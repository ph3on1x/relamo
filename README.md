# relamo has moved

This project now lives in **[ph3on1x/agent-plugins-skills](https://github.com/ph3on1x/agent-plugins-skills/tree/main/skills/relamo)**, together with my other
agent skills and plugins. This repository is archived and no longer updated. The full git history and
release tags were carried over to the new repository.

## Install

Claude Code:

```text
/plugin marketplace add ph3on1x/agent-plugins-skills
/plugin install relamo@ph3on1x
```

Codex, Cursor, Gemini CLI, Antigravity and other agents:

```bash
npx skills add ph3on1x/agent-plugins-skills --skill relamo
```

## Already installed from this repository?

Nothing to do: this repository's marketplace now forwards to the new location, so `/plugin marketplace update relamo` keeps `relamo@relamo` updated. To move to the new marketplace, run `claude plugin uninstall relamo@relamo`, then the Claude Code commands above.

`gemini extensions install` from this repository and `scripts/setup-platforms.sh` are retired: Gemini CLI, Codex and Cursor users install the skills with `npx skills` as shown above.
