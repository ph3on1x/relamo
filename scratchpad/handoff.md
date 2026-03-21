# Handoff: relamo plugin v0.1.0 — initial implementation

> Last updated by /compress on 2026-03-21 23:30

## Goal
Implement a Claude Code plugin called "relamo" that brings the Recursive Language Model (RLM) pattern to Claude Code — programmatic codebase exploration via a persistent Python REPL where the entire codebase is concatenated into a `context` variable and Claude writes Python to explore it iteratively.

## Completed
- **Plugin scaffold**: Created `.claude-plugin/plugin.json` with name, description, version 0.1.0, author Dennis Nasarov, MIT license
- **REPL engine** (`skills/relamo/scripts/repl.py`): ~250-line uv single-file script (PEP 723) with `dill>=0.3.8` dependency. Two commands:
  - `init --codebase-dir <path>` — gathers codebase via `git ls-files` (or walk with default excludes), skips binaries/large files, concatenates with `=== path ===` delimiters, persists to state dir
  - `execute "<code>" --state-dir <dir>` — runs Python in sandboxed namespace with `dill`-based state persistence across calls
  - Helpers: `context`, `list_files()`, `extract_file(path)`, `search(pattern)`, `llm_query(prompt)`, `llm_query_batched(prompts)`, `recursive_llm(query, sub_context)`, `FINAL(answer)`, `FINAL_VAR(var_name)`, `config`
  - Sandboxing: module whitelist (`re`, `json`, `math`, `collections`, etc.), blocks `eval`/`exec`/`compile`, filtered `__import__`
  - Output captured via `io.StringIO`, truncated to `config["max_output_chars"]`
- **SKILL.md** (`skills/relamo/SKILL.md`): ~1,800 words. Iron Law ("NO ANSWER WITHOUT CONTEXT EXPLORATION FIRST"), argument parsing, initialization, 6-step REPL loop, function table, emergent strategies, safety guardrails, rationalizations table, output format
- **Reference docs**:
  - `references/repl-setup.md` — REPL architecture, context loading modes, helper signatures, sandboxing details, troubleshooting
  - `references/safety-config.md` — defaults table (recursion_limit=1, max_iterations=15, timeout=120s, max_output_chars=5000), cost estimates, recursion depth vs accuracy, loop detection guidance
  - `references/system-prompt.md` — template for `recursive_llm()` sub-calls via `claude -p`
- **Research preserved** in `scratchpad/rlm-research.md` and `scratchpad/skills-research.md` (untouched)
- **Verification**: Tested init (8 files, 61K chars), execute, state persistence (variables survive across calls), `extract_file()`, `search()`, `FINAL()` marker, sandboxing (os blocked, re allowed)
- **End-to-end test**: `/relamo "what does this project do?"` completed in 1m 16s — 5 iterations, correct structured output with Exploration Summary, Answer, Evidence sections

## In Progress
Nothing — v0.1.0 is fully implemented and verified.

## Decisions Made
- **Full concat over index+drill**: Entire codebase concatenated into one `context` string with `=== path ===` delimiters, matching the MIT RLM paper. User chose this over index-based or hybrid approaches.
- **Real Python REPL over native tools**: Uses actual Python execution via Bash (not just Claude Code's Read/Grep). Enables variable persistence, arbitrary processing, batch LLM calls.
- **uv single-file script (PEP 723)**: `repl.py` declares `dill>=0.3.8` inline, runs via `uv run` — zero environment setup, env-independent.
- **`dill` over `pickle`**: Handles lambdas, closures, complex types that pickle can't serialize.
- **`claude -p` for LLM sub-calls**: `llm_query()` and `recursive_llm()` shell out to `claude -p --no-session-persistence --output-format text`. Proven pattern from superpowers testing infrastructure.
- **Codebase-first default**: Context defaults to `${CLAUDE_WORK_DIR}` (current project). User runs `/relamo "fix the bug"` and the codebase is gathered automatically.
- **Subcommand CLI** (`init`/`execute`): Chosen over `--init`/`--execute` flags for cleaner argparse usage.

## Next Steps
1. **Git init + first commit**: The project has no git repo yet. Initialize and commit v0.1.0.
2. **Publish as installable plugin**: Consider publishing to a registry or GitHub for `claude /install-plugin` usage.
3. **Test on a large real codebase**: The end-to-end test was on the small relamo project itself. Test against a 1M+ char codebase to exercise `llm_query()`, chunking, and `recursive_llm()`.
4. **v0.2.0 improvements** (future):
   - Agent-based `recursive_llm()` instead of `claude -p` (uses Claude Code's Agent tool for richer sub-instances)
   - Parallel `llm_query_batched()` using background tasks
   - Budget tracking (programmatic `max_budget_usd` enforcement)
   - Loop detection in repl.py itself (detect repeated code/output)

## Blockers / Open Questions
- **`claude -p` nesting**: When `recursive_llm()` calls `claude -p` from inside a Bash call that's inside a Claude Code session, no issues observed yet — but untested at depth > 1.
- **Very large codebases**: 50MB context limit may need tuning for monorepos. The REPL loads the full context string into memory on each `execute` call.
- **Plugin installation**: Not yet tested via `claude /install-plugin` — only via `claude --plugin-dir`.

## References
- `.claude-plugin/plugin.json` — plugin manifest, defines name/version/author
- `skills/relamo/SKILL.md` — core skill definition, the behavioral contract for how Claude executes the RLM loop
- `skills/relamo/scripts/repl.py` — REPL engine, most complex file, handles codebase gathering + sandboxed execution + state persistence
- `skills/relamo/references/repl-setup.md` — REPL architecture documentation, helper function signatures
- `skills/relamo/references/safety-config.md` — safety defaults, cost estimates, recursion tradeoffs
- `skills/relamo/references/system-prompt.md` — template for recursive sub-calls
- `scratchpad/rlm-research.md` — RLM concept research (MIT paper, implementations, mapping to Claude Code)
- `scratchpad/skills-research.md` — Claude Code skill architecture research (patterns, best practices, eval methodology)
