# Claude Code Skills — Research & Best Practices

> Last updated by /write on 2026-03-21 13:00
> Source: /isolate research session — 3 parallel agents investigating skill structure, existing patterns, and triggering/descriptions

## Summary

Comprehensive research on Claude Code skill architecture, best practices, and patterns extracted from the plugin-dev, superpowers, and wisci plugin ecosystems. This document captures everything needed to build a high-quality `/relamo` skill implementing the Recursive Language Model pattern.

## YAML Frontmatter Fields

| Field | Required | Purpose |
|-------|----------|---------|
| `name` | Yes | Kebab-case identifier, used for discovery and invocation |
| `description` | Yes | Primary trigger mechanism — third-person, with quoted trigger phrases |
| `version` | No | Semantic versioning (default `0.1.0`) |
| `argument-hint` | No | Documents expected arguments and defaults for the user |
| `allowed-tools` | No | Restricts available tools (e.g., `Read`, `Bash(git *)`) |
| `compatibility` | No | Required tools or dependencies (rarely needed) |

### Description Writing Rules

- Always third-person: `"This skill should be used when the user asks to..."`
- Include specific quoted trigger phrases users would actually say
- Be "pushy" — Claude undertriggers by default; descriptions must be aggressive about when to activate
- Substantive queries only — simple one-step tasks won't trigger skills regardless of description quality
- Append brief context about what the skill does or enables

**Strong example:**
```yaml
description: This skill should be used when the user asks to "create a hook", "add a PreToolUse/PostToolUse/Stop hook", "validate tool use", "implement prompt-based hooks", or mentions hook events (PreToolUse, PostToolUse, Stop, SubagentStop, SessionStart, SessionEnd).
```

**Weak example (avoid):**
```yaml
description: Use this skill when working with hooks.  # Wrong person, vague, no trigger phrases
```

## Progressive Disclosure (3 Levels)

1. **Level 1 — Metadata** (~100 words): name + description, always loaded at plugin init
2. **Level 2 — SKILL.md body** (1,500–2,000 words ideal, <5,000 max): core concepts, essential procedures, quick reference tables, pointers to references
3. **Level 3 — Bundled resources** (unlimited): references/, scripts/, examples/, assets/ loaded on demand by Claude

### Directory Structure

```
skill-name/
├── SKILL.md              # YAML frontmatter + markdown instructions (required)
├── references/           # Documentation loaded as needed (2,000–5,000+ words each)
├── scripts/              # Executable code (Python/Bash) for deterministic operations
├── examples/             # Working code examples
└── assets/               # Templates, boilerplate, images (NOT loaded into context)
```

### When to Use Each Directory

- **references/**: Documentation Claude should reference while working — schemas, API specs, detailed guides, advanced patterns. Include grep patterns in SKILL.md if files are large.
- **scripts/**: Same code rewritten repeatedly, deterministic operations, complex multi-step automation. Token-efficient (can execute without loading full context).
- **examples/**: Working code that demonstrates patterns. Complete and executable.
- **assets/**: Files used in output but NOT loaded into context — templates, brand assets, fonts.

## Writing Style

- **Imperative/infinitive form** in SKILL.md body: "Parse the frontmatter." NOT "You should parse the frontmatter."
- **Third-person** in YAML description only
- Keep SKILL.md lean — move detailed content to references/ to avoid bloat
- Never duplicate information across SKILL.md and references/
- Always include an "Additional Resources" section pointing to references/, examples/, scripts/

## Environment Variables

- `$ARGUMENTS` — Raw user arguments passed to the skill
- `${CLAUDE_SKILL_DIR}` — Absolute path to the skill directory
- `${CLAUDE_WORK_DIR}` — Current working directory
- `${CLAUDE_PLUGIN_ROOT}` — Absolute path to the plugin directory (for commands/hooks)

## Argument Handling Patterns

**Mode detection** (from wisci:select):
```markdown
Check `$ARGUMENTS`:
- **Empty or blank:** execute **bare mode** (default behavior)
- **Has content:** execute **targeted mode** (process arguments)
```

**argument-hint examples:**
```yaml
argument-hint: "[topic] (optional — omit for codebase primer)"
argument-hint: "[push] [commit message] (optional — omit push to skip)"
argument-hint: "description of what to externalize"
```

## Patterns from Existing Skills

### Iron Laws (Hard Gates)
State immutable rules that prevent skipping critical steps:
- TDD: "NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST"
- Debugging: "NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST"
- Brainstorming: "Do NOT invoke any implementation skill... until you have presented a design and the user has approved it"

### Rationalizations Tables
Common excuses paired with reality checks. Used in TDD and systematic-debugging to prevent shortcuts:

| Thought | Reality |
|---------|---------|
| "Too simple to test" | Simple code breaks. Test takes 30 seconds. |
| "Quick fix for now" | First fix sets the pattern. |
| "I'll test after" | Tests passing immediately prove nothing. |

### Flowcharts for Decision Trees
Multiple skills use graphviz `digraph` notation for decision logic:
- brainstorming: visual vs text questions
- dispatching-parallel-agents: when to parallelize
- subagent-driven-development: per-task process flow
- using-superpowers: skill invocation flow

### Checklist Enforcement via TodoWrite
Skills with multi-step checklists create explicit TodoWrite tasks per item for tracking progress.

### Subagent Isolation Pattern
Consistent across isolate, dispatching-parallel-agents, subagent-driven-development:
- Subagent gets isolated context (no session history)
- Precisely crafted prompt with specific scope
- Clear output format expectations
- Parallel execution when tasks are independent

### Two-Stage Review Pattern
From subagent-driven-development:
1. Spec compliance review (does code match spec?)
2. Code quality review (is implementation well-built?)
- Each stage can loop until approved — different concerns, different reviewers

### Skill Transitions
Explicit handoffs between skills:
- brainstorming → writing-plans (after design approval)
- writing-plans → subagent-driven-development OR executing-plans
- executing-plans → finishing-a-development-branch

### Output Format Specs
Every well-crafted skill defines its exact output structure — headings, sections, format.

### Model Selection by Task Complexity
From subagent-driven-development:
- Mechanical tasks (1-2 files, clear spec) → cheap, fast model
- Integration tasks (multiple files) → standard model
- Architecture/design/review tasks → most capable model

## Eval & Testing Methodology

### Trigger Rate Testing (from skill-creator)
1. Generate 20 queries: 8-10 should-trigger, 8-10 should-not-trigger
2. Split 60/40 train/test
3. Run each query 3 times for reliability
4. 5-iteration optimization loop on description
5. Select best description by test score (not train) to avoid overfitting

### Query Quality
- Include file paths, personal context, column names, backstory
- Mix lengths, casual speech, typos, abbreviations
- Near-miss should-not-trigger queries are most valuable
- Simple queries don't test anything (too easy to distinguish)

### Grading Criteria
- **PASS**: Transcript clearly demonstrates expectation with specific evidence
- **FAIL**: No evidence, contradicts expectation, or superficial match
- **When uncertain**: Burden of proof is on the expectation

### Eval Schema (evals.json)
```json
{
  "skill_name": "example-skill",
  "evals": [
    {
      "id": 1,
      "prompt": "User's example prompt",
      "expected_output": "Description of expected result",
      "files": ["evals/files/sample.txt"],
      "expectations": ["The output includes X", "The skill used script Y"]
    }
  ]
}
```

## Anti-Patterns to Avoid

1. **Bloated SKILL.md** — Never exceed 3,000 words without references/; ideally 1,500–2,000
2. **Vague descriptions** — "Provides guidance for X" triggers nothing
3. **Second-person writing** — "You should..." anywhere in the skill
4. **Unreferenced resources** — Creating references/ files but never mentioning them in SKILL.md
5. **Duplicated information** — Same content in SKILL.md and references/
6. **Missing Additional Resources section** — Always document available references, examples, scripts

## Validation Checklist

**Structure:**
- [ ] SKILL.md exists with valid YAML frontmatter
- [ ] Frontmatter has `name` and `description` fields
- [ ] All referenced files actually exist

**Description Quality:**
- [ ] Third person ("This skill should be used when...")
- [ ] Specific quoted trigger phrases
- [ ] Concrete scenarios listed
- [ ] Not vague or generic

**Content Quality:**
- [ ] Imperative/infinitive form throughout body
- [ ] Body is 1,500–2,000 words (under 5k max)
- [ ] Detailed content in references/
- [ ] SKILL.md references resources clearly

**Progressive Disclosure:**
- [ ] Core concepts in SKILL.md
- [ ] Detailed docs in references/
- [ ] Working code in examples/
- [ ] Utilities in scripts/

## Implications for /relamo Skill Design

1. **Keep SKILL.md lean** (~1,500–2,000 words) with the core RLM loop; move REPL setup, system prompts, safety configs to references/
2. **Description must be pushy** — triggers: "recursive language model", "RLM", "context as variable", "REPL loop", "process large context", "explore large file"
3. **Use mode detection** — empty args → interactive mode; args → specify context file/query
4. **Model after wisci:isolate** for subagent spawning (parallel agents with isolated context)
5. **Model after superpowers:systematic-debugging** for sequential phase structure
6. **Include Iron Law** — "NO ANSWER WITHOUT CONTEXT EXPLORATION FIRST"
7. **Define output format** explicitly (intermediate REPL results + final synthesized answer)
8. **Safety guardrails** — recursion limit, max iterations, budget cap in references/
9. **Progressive disclosure** — SKILL.md has loop overview; references/ has REPL implementation, system prompts, safety config

## Key Details

- **Decisions**: Target 1,500–2,000 word SKILL.md with references/ for detailed content. Use mode detection pattern from wisci:select. Iron Law pattern from superpowers for enforcing exploration-before-answer.
- **Open questions**: Should /relamo use a real Python REPL (via Bash) or map to Claude Code native tools? How to handle `llm_query()` — Agent tool or `claude -p`? What sandboxing for Python REPL?

## References

- `~/.claude/plugins/cache/claude-plugins-official/plugin-dev/78497c524da3/skills/skill-development/SKILL.md` — Skill development best practices, writing style, progressive disclosure
- `~/.claude/plugins/cache/claude-plugins-official/skill-creator/78497c524da3/skills/skill-creator/SKILL.md` — Skill creation workflow, description optimization, eval methodology
- `~/.claude/plugins/cache/claude-plugins-official/plugin-dev/78497c524da3/skills/plugin-structure/SKILL.md` — Plugin structure, manifest, component organization
- `~/.claude/plugins/cache/claude-plugins-official/plugin-dev/78497c524da3/skills/plugin-structure/references/manifest-reference.md` — Plugin manifest fields
- `~/.claude/plugins/cache/claude-plugins-official/plugin-dev/78497c524da3/skills/plugin-structure/references/component-patterns.md` — Component organization patterns
- `~/.claude/plugins/cache/claude-plugins-official/skill-creator/78497c524da3/skills/skill-creator/references/schemas.md` — Eval JSON schemas (evals.json, grading.json, benchmark.json)
- `~/.claude/plugins/cache/claude-plugins-official/superpowers/5.0.4/skills/brainstorming/SKILL.md` — Flowchart-driven checklist, visual companion, hard design gate
- `~/.claude/plugins/cache/claude-plugins-official/superpowers/5.0.4/skills/systematic-debugging/SKILL.md` — 4-phase sequential debugging, Iron Law, rationalizations table
- `~/.claude/plugins/cache/claude-plugins-official/superpowers/5.0.4/skills/test-driven-development/SKILL.md` — Red-Green-Refactor, Iron Law, good test patterns
- `~/.claude/plugins/cache/claude-plugins-official/superpowers/5.0.4/skills/dispatching-parallel-agents/SKILL.md` — Domain grouping, parallel dispatch, agent prompt structure
- `~/.claude/plugins/cache/claude-plugins-official/superpowers/5.0.4/skills/subagent-driven-development/SKILL.md` — Per-task implementer + two-stage review, model selection
- `~/.claude/plugins/cache/claude-plugins-official/superpowers/5.0.4/skills/executing-plans/SKILL.md` — Plan loading, task execution, verification
- `~/.claude/plugins/cache/claude-plugins-official/superpowers/5.0.4/skills/writing-plans/SKILL.md` — File structure, bite-sized steps, plan review loop
- `~/.claude/plugins/cache/wisci-framework/wisci/1.2.1/skills/isolate/SKILL.md` — Subagent research delegation, parallel spawning, inline results
- `~/.claude/plugins/cache/wisci-framework/wisci/1.2.1/skills/write/SKILL.md` — Context externalization, slug inference, merge procedure
- `~/.claude/plugins/cache/wisci-framework/wisci/1.2.1/skills/select/SKILL.md` — Context loading, bare/targeted modes, staleness detection
- `~/.claude/plugins/cache/wisci-framework/wisci/1.2.1/skills/commit/SKILL.md` — Conventional commits with AI context tracking
