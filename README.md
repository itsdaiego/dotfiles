# dotfiles

Personal dotfiles that make my life easier! :D

## Agent setup

This repository keeps the portable configuration for the company and personal Codex homes, Claude Code, and both Pi profiles in one place. It includes global instructions, settings, skills, prompts, extensions, MCP server definitions that do not contain credentials, shared agent customizations, launchers, and the Pi extension package lock.

Authentication files, OAuth state, session histories, caches, databases, downloaded plugins, generated system skills, and per-machine trust state stay outside Git.

Clone the repository at `~/Documents/code-stuff/dotfiles`, then run:

```sh
./scripts/install-agent-configs.sh
```

The installer links every tracked file under `.agent-customizations`, `.codex`, `.codex-personal`, `.claude`, `.pi`, and `.local/bin` into the matching path in the home directory. It also shares `AGENTS.md` and skills between the personal Codex home and the managed Pi/default Codex sources. It preserves an existing file, link, or directory in a timestamped directory under `~/.dotfiles-backups/` before replacing it. Future pulls update the linked files immediately.

When Codex, Claude Code, or Pi starts inside Herdr, the shared integration labels its tab with the harness name. Herdr combines the project workspace and harness on the bold top line, such as `chessan · codex`. The first prompt asks the model to infer a short task name and call `herdr agent rename`, which puts the task description on the lower line.

`codex-company` uses `~/.codex`, while `codex-personal` uses `~/.codex-personal`; their authentication stays separate. Claude Code keeps its authentication in its own home-directory state. Pi keeps authentication and MCP credentials under each profile. Sign in separately on a new machine after installing the links.

The Pi dependency versions live in `.pi/agent/npm/package-lock.json`. Pi installs the packages listed in its settings when it starts. If a local Pi installation needs the shared dependency tree directly, run `npm install --prefix ~/.pi/agent/npm` after reviewing the lockfile.

See `docs/agent-config-maintenance.md` before changing or refreshing the shared harness setup.
