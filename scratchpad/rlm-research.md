# Recursive Language Models (RLM) — Research

> Last updated by /write on 2026-03-21 12:00
> Source: /isolate research session — 3 parallel agents investigating RLLM concepts, Claude Code skill architecture, and existing loop/recursive patterns

## Summary

Recursive Language Models (RLMs) are an inference-time pattern where context is stored as a variable in a REPL environment, and the LLM writes Python code to programmatically explore, search, chunk, and recursively process it. This document captures the full research for building a Claude Code skill that implements this pattern — allowing Claude to call itself in a REPL loop.

## Core Concept: Context-as-Variable

Instead of stuffing all context into the LLM prompt (which causes "context rot" at long lengths), RLM stores context as a Python variable (`context`) in a REPL. The LLM receives only the query + instructions and writes code to interact with the data.

**Key design choices (MIT research)**:
1. Treat the prompt as a Python variable processable in arbitrary REPL flows
2. Allow the REPL environment to make calls back to the LLM

**Comparison**:

| Aspect | Traditional LLM | RLM |
|--------|----------------|-----|
| Context handling | Fixed window; entire prompt at input | External variable; programmatically accessed |
| Recursion | Limited to function-calling loops | Native recursion with code generation |
| Scaling | Hits hard context limit | Linear scaling to 10M+ tokens |
| Intermediate state | Lost between calls | Persisted in REPL as variables |
| Cost at scale | Exponential | ~80-90% reduction |

## The REPL Interaction Loop

```
User query + system prompt (small — no context!)
    ↓
LLM writes: ```repl print(context[:500]) ```        ← peek
    ↓
REPL returns: "first 500 chars of context..."
    ↓
LLM writes: ```repl re.findall(r'pattern', context) ```  ← grep
    ↓
REPL returns: ['match1', 'match2']
    ↓
LLM writes: ```repl                                  ← partition + map
chunks = [context[i:i+5000] for i in range(0, len(context), 5000)]
results = [llm_query(f"Summarize: {c}") for c in chunks]
```
    ↓
REPL returns: results stored as variable
    ↓
LLM: FINAL(synthesized answer)
```

Each iteration appends LLM output as "assistant" and REPL output as "user", building conversation history.

## Functions Available in the REPL

| Function | What it does |
|----------|-------------|
| `context` (variable) | The full document/data as a string |
| `llm_query(prompt)` | Single LLM completion (no REPL, fast) |
| `llm_query_batched(prompts)` | Parallel LLM calls |
| `recursive_llm(query, sub_context)` / `rlm_query(prompt)` | Spawns a child RLM with its own REPL |
| `FINAL(answer)` | Emit final answer (parsed from text, not code) |
| `FINAL_VAR(var_name)` | Return a REPL variable as the answer |

## Emergent Strategies

The LLM discovers these strategies on its own:

1. **Peeking**: `print(context[:2000])` — sample beginning to understand structure
2. **Grepping**: `re.findall(r'pattern', context)` — keyword/regex search
3. **Partition + Map**: chunk context, call `llm_query` or `llm_query_batched` on each chunk, aggregate
4. **Summarization**: recursively summarize sections, then synthesize
5. **Programmatic Processing**: Python for deterministic computations (math, parsing, diffs)

## Key Implementations

### MIT RLM (Academic Reference)
- **Paper**: arXiv:2512.24601
- **Blog**: alexzhang13.github.io/blog/2025/rlm/
- **Repos**: `alexzhang13/rlm` (full), `alexzhang13/rlm-minimal` (minimal)
- Supports up to 10M+ tokens per query without degradation
- Post-trained variant (RLM-Qwen3-8B) outperformed base by ~28%
- Default: `max_depth=1`, `max_iterations=30`, output truncated to 20K chars/turn

### ysz/recursive-llm (Community Implementation)
- **Repo**: `github.com/ysz/recursive-llm`
- Uses RestrictedPython for sandboxing
- Universal LLM support via LiteLLM
- Key files: `src/rlm/core.py`, `src/rlm/repl.py`, `src/rlm/prompts.py`, `src/rlm/parser.py`

### MIT Implementation Details

**REPL Executor** (`rlm/repl.py`):
- Writes context to temp file on disk, loads into namespace via `exec`
- Sandboxed `globals` dict blocking `eval`, `exec`, `input`, `compile`, `globals`, `locals`
- Captures stdout/stderr via `io.StringIO`
- Variables persist across calls in `self.locals`

**Context loading**:
```python
def load_context(self, context_str=None):
    context_path = os.path.join(self.temp_dir, "context.txt")
    with open(context_path, "w") as f:
        f.write(context_str)
    context_code = (
        f"import os\n"
        f"with open(r'{context_path}', 'r') as f:\n"
        f"    context = f.read()\n"
    )
    self.code_execution(context_code)
```

**Recursive self-call** (ysz):
```python
async def recursive_llm(sub_query: str, sub_context: str) -> str:
    sub_rlm = RLM(
        model=self.recursive_model,
        max_depth=self.max_depth,
        _current_depth=self._current_depth + 1,
    )
    return await sub_rlm.acomplete(sub_query, sub_context)
```

**Main loop** (MIT minimal):
```python
def completion(self, context, query=None):
    self.messages = self.setup_context(context, query)
    for iteration in range(self._max_iterations):
        response = self.llm.completion(
            self.messages + [next_action_prompt(query, iteration)]
        )
        code_blocks = find_code_blocks(response)
        if code_blocks:
            for code in code_blocks:
                result = repl_env.code_execution(code)
                messages.append({
                    "role": "user",
                    "content": f"REPL output:\n{result}"
                })
        final_answer = check_for_final_answer(response, repl_env)
        if final_answer:
            return final_answer
```

**FINAL parsing**:
```python
def find_final_answer(text, environment=None):
    final_var_pattern = r"^\s*FINAL_VAR\((.*?)\)"
    match = re.search(final_var_pattern, text, re.MULTILINE | re.DOTALL)
    if match:
        variable_name = match.group(1).strip().strip('"').strip("'")
        result = environment.execute_code(f"print(FINAL_VAR({variable_name!r}))")
        return result.stdout.strip()
    final_pattern = r"^\s*FINAL\((.*)\)\s*$"
    match = re.search(final_pattern, text, re.MULTILINE | re.DOTALL)
    if match:
        return match.group(1).strip()
```

## System Prompt (MIT Minimal)

```
You are tasked with answering a query with associated context. You can access,
transform, and analyze this context interactively in a REPL environment that can
recursively query sub-LLMs, which you are strongly encouraged to use as much as
possible. You will be queried iteratively until you provide a final answer.

The REPL environment is initialized with:
1. A `context` variable that contains extremely important information about your query.
2. A `llm_query` function that allows you to query an LLM (that can handle around
   500K chars) inside your REPL environment.
3. The ability to use `print()` statements to view the output of your REPL code.

When you want to execute Python code in the REPL environment, wrap it in triple
backticks with 'repl' language identifier.
```

## Risks and Mitigations

### Infinite Loops / Runaway Recursion
- **Mitigation**: Hard `recursion_limit` (default 3-5), `max_iterations` (default 10-30), `max_timeout` (seconds)
- Example: 10k tokens/cycle × 100 cycles = 1M tokens wasted

### Token Explosion
- **Mitigation**: Force subagent result summarization (<500 tokens), REPL output truncation (2K-20K chars), prune intermediate state

### Coherence Degradation at Depth
- Depth 1: ~95% accuracy, Depth 3: ~82%, Depth 4+: significant hallucination risk
- **Mitigation**: Quality gates between levels, practical max depth 2-3

### Cost Runaway
- **Mitigation**: `max_budget_usd` per invocation, anomaly detection, per-user rate limits
- Paper acknowledgment: "We do not currently have strong guarantees about controlling either the total API cost or the total runtime"

### Recommended Safety Defaults
```python
config = {
    "recursion_limit": 3,
    "max_iterations": 10,
    "timeout_seconds": 300,
    "max_output_chars": 2000,
    "max_budget_usd": 5.00,
    "loop_detection": True,
}
```

## Claude Code Skill Architecture

### Skill File Structure
```
skill-name/
├── SKILL.md              # YAML frontmatter + instructions
├── references/           # On-demand documentation
├── scripts/              # Executable code
└── assets/               # Templates, boilerplate
```

### YAML Frontmatter Fields
```yaml
---
name: skill-name
description: "Triggers skill selection; 3rd person phrasing"
version: "0.1.0"
argument-hint: "[arg1] [arg2]"
allowed-tools:
  - Read
  - Write
  - Bash(git *)
  - Agent
---
```

### Environment Variables in Skills
- `$ARGUMENTS` — User arguments passed to skill
- `${CLAUDE_SKILL_DIR}` — Absolute path to skill directory
- `${CLAUDE_WORK_DIR}` — Current working directory

### Self-Invocation Mechanisms
1. **Agent tool** — Spawn isolated subagents with fresh context windows
2. **`claude -p`** — Non-interactive CLI invocation via Bash (`--no-session-persistence`, `--max-budget-usd`, `--output-format=json`)
3. **CronCreate** — Schedule recurring prompts (auto-expires 7 days)
4. **SendMessage** — Inter-agent communication

## Existing Loop Patterns in Claude Code

### Ralph Loop (Stop Hook Pattern)
- Uses a `Stop` hook that intercepts session exit
- Feeds same prompt back to Claude on each iteration
- State in `.claude/ralph-loop.local.md` (YAML: `active`, `iteration`, `max_iterations`, `session_id`)
- Completion via `<promise>TAG</promise>` exact match or iteration limit
- Session-isolated via session_id check

### Superpowers Subagent-Driven Development
- Controller dispatches implementer → spec reviewer → code quality reviewer per task
- Review loop: if reviewer rejects, implementer fixes → re-review
- Subagents receive FULL task text in prompt (not file references)
- Reviewers explicitly skeptical: "do NOT trust the report"

### Test Infrastructure
- Uses `claude -p` in bash with `timeout` + output capture
- Verifies tool invocations by inspecting `.jsonl` session transcript

## Mapping RLM to Claude Code

| RLM Concept | Claude Code Equivalent |
|-------------|----------------------|
| `context` variable in REPL | Files on disk + codebase |
| LLM writes Python code | Claude writes bash/tool calls |
| `print(context[:500])` | `Read` tool (peek at file) |
| `re.findall(pattern, context)` | `Grep` tool |
| `recursive_llm(query, chunk)` | Agent sub-tasks |
| `FINAL(answer)` | Final response to user |
| REPL output truncation | Tool output limits |
| Iterative REPL loop | Multi-turn conversation with tool use |

**Key difference**: Claude Code uses structured tool-use rather than raw Python. RLM is more flexible (arbitrary code, variables as scratch space) but requires sandboxing.

**Core transferable insight**: Don't stuff everything into the prompt. Store data externally, let the LLM programmatically explore it, and accumulate intermediate results in variables.

## Open Questions

- Should we implement a real Python REPL (via Bash) or map to Claude Code's native tools?
- How to handle `llm_query()` — spawn via Agent tool or `claude -p`?
- What sandboxing approach for the Python REPL within Claude Code?
- Should the skill support both "context from file" and "context from stdin/argument"?
- How to surface cost/token usage to the user during iteration?

## References

- arXiv:2512.24601 — MIT RLM paper, foundational research
- `github.com/alexzhang13/rlm` — MIT full implementation (rlm/core/rlm.py, rlm/environments/local_repl.py, rlm/utils/prompts.py, rlm/utils/parsing.py)
- `github.com/alexzhang13/rlm-minimal` — MIT minimal implementation (rlm/rlm_repl.py, rlm/repl.py, rlm/utils/prompts.py)
- `github.com/ysz/recursive-llm` — Community implementation (src/rlm/core.py, src/rlm/repl.py, src/rlm/prompts.py, src/rlm/parser.py)
- alexzhang13.github.io/blog/2025/rlm/ — MIT blog post
- primeintellect.ai/blog/rlm — Prime Intellect analysis
- `~/.claude/plugins/cache/claude-plugins-official/ralph-loop/78497c524da3/` — Ralph Loop plugin (stop hook pattern)
- `~/.claude/plugins/cache/claude-plugins-official/superpowers/5.0.4/skills/subagent-driven-development/` — Superpowers subagent orchestration
