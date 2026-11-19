# Maintaining the shared agent configuration

The repository is the source of truth for the portable company/personal Codex, Claude Code, and Pi setup. Home-directory files point into this checkout, so edits to a managed file are visible in Git immediately.

## Pull updates on another Mac

Use the repository's default branch, which is currently `master`:

```sh
cd ~/Documents/code-stuff/dotfiles
git pull --ff-only origin master
./scripts/install-agent-configs.sh
./scripts/verify-agent-configs.sh
```

The installer backs up conflicting files under `~/.dotfiles-backups/`. It does not copy authentication or session state. Sign in to each harness separately when the machine has no credentials yet.

Use `codex-company` for the `~/.codex` home and `codex-personal` for the isolated `~/.codex-personal` home. The installer shares instructions and skills but leaves their authentication separate.

## Change shared configuration

Create a dedicated branch and a disposable worktree under `/tmp/worktrees/dotfiles/<task>`. On macOS, Git may display this as `/private/tmp/worktrees/dotfiles/<task>`. Do not commit from `master` or from the primary checkout. Change the tracked source in the temporary worktree, run `./scripts/verify-agent-configs.sh`, then commit the reviewed files.

Every writable worktree must have its own local branch. The branch preserves committed work if the temporary directory disappears, but it does not preserve uncommitted files. Before moving, removing, or abandoning a dirty worktree, run `scripts/backup-worktree-state.sh <worktree-path>`. The script stores binary patches and an archive of untracked files under the repository's common Git directory. Committing is also valid when that commit is authorized. A local branch is not a remote backup; pushing still requires explicit authorization.

Installed Pi, Claude Code, and Codex files must point to the primary checkout at `~/Documents/code-stuff/dotfiles`, never to a temporary worktree. `scripts/install-agent-configs.sh` resolves the common Git directory so it uses the primary checkout even when invoked from a linked worktree.

`pi` and `pi-work` share `~/.pi/agent`, including sessions, plugins, MCP configuration, and skills. The installer links `~/.pi/pi-work` to that root. Do not add files under `.pi/pi-work`.

`pi-personal` has its own root at `~/.pi/pi-personal`. Put shared extensions, prompts, skills, agents, and themes under `.pi/agent/`, then add a relative symlink from `pi-personal` when it needs the resource. Keep `pi-personal` settings separate when the difference is intentional.

Both Codex homes and Claude Code use the shared `.agent-customizations` directory for cross-harness behavior. Add portable skills and hook scripts there when the harnesses can use the same implementation. Keep generated first-party skills and downloaded plugins out of the repository.

## Refresh Herdr integrations

Herdr owns the lifecycle integration files that report agent state. Refresh them with the installed Herdr CLI:

```sh
herdr integration install pi
herdr integration install claude
herdr integration install codex
herdr integration status
```

The managed files identify themselves with `HERDR_INTEGRATION_ID` and `HERDR_INTEGRATION_VERSION`. Do not add custom behavior to those files because the next Herdr update overwrites them. Custom Herdr behavior lives under `.config/herdr/scripts/`. The task-name sources are `.config/herdr/scripts/auto-name/user_prompt_hook.py` and `.config/herdr/scripts/auto-name/pi-extension.ts`; `.agent-customizations/herdr-auto-name/user_prompt_hook.py` and `.pi/agent/extensions/herdr-auto-name.ts` are compatibility entrypoints.

After a refresh, inspect the Git diff. Keep the `UserPromptSubmit` entries in `.claude/settings.json`, `.codex/hooks.json`, and `.codex-personal/hooks.json`. Keep `[features].hooks = true` in both Codex `config.toml` files, and keep the `herdr-auto-name.ts` link in both Pi profiles. The installer manages only `.config/herdr/scripts`, so it does not replace machine-local Herdr configuration or state. Run the verification script before committing.

### Preserve the harness tab label

Set a Herdr tab label from the harness that started the session, not from Herdr's current agent record. At startup, that record can still describe the harness that previously occupied the pane. Reading it can label a new Pi, Claude, or Codex session as Claude until a later state update.

`.config/herdr/scripts/auto-name/set_harness_tab_label.py` renames the current `HERDR_TAB_ID` with the supplied, fixed harness name. The Claude and both Codex `SessionStart` hooks call it directly. The Pi auto-name extension labels its tab `pi` before looking up naming state. Keep these calls when changing integrations or hooks so every shared machine gets the correct label as soon as a harness opens.

## Files that never belong in Git

Do not add authentication files, OAuth state, MCP credentials, session transcripts, histories, caches, SQLite databases, downloaded plugins, generated system skills, machine installation IDs, or per-machine trust files. The tracked MCP configuration may name environment variables, but it must never contain the token values.
