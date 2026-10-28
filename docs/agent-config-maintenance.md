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

Create a dedicated worktree and branch. Do not commit from `master` or from the primary checkout. Change the tracked source in the worktree, run `./scripts/verify-agent-configs.sh`, then commit the reviewed files.

Pi has separate `pi-personal` and `pi-work` roots. Put shared extensions, prompts, skills, agents, and themes under `.pi/agent/`. Add a relative symlink from both profile directories, then verify that the two profile trees match. Keep profile-specific settings separate when the difference is intentional.

Both Codex homes and Claude Code use the shared `.agent-customizations` directory for cross-harness behavior. Add portable skills and hook scripts there when the harnesses can use the same implementation. Keep generated first-party skills and downloaded plugins out of the repository.

## Refresh Herdr integrations

Herdr owns the lifecycle integration files that report agent state. Refresh them with the installed Herdr CLI:

```sh
herdr integration install pi
herdr integration install claude
herdr integration install codex
herdr integration status
```

The managed files identify themselves with `HERDR_INTEGRATION_ID` and `HERDR_INTEGRATION_VERSION`. Do not add custom behavior to those files because the next Herdr update overwrites them. The task-name behavior lives beside them in `.agent-customizations/herdr-auto-name/user_prompt_hook.py` and `.pi/agent/extensions/herdr-auto-name.ts`.

After a refresh, inspect the Git diff. Keep the `UserPromptSubmit` entries in `.claude/settings.json`, `.codex/hooks.json`, and `.codex-personal/hooks.json`. Keep `[features].hooks = true` in both Codex `config.toml` files, and keep the `herdr-auto-name.ts` link in both Pi profiles. Run the verification script before committing.

## Files that never belong in Git

Do not add authentication files, OAuth state, MCP credentials, session transcripts, histories, caches, SQLite databases, downloaded plugins, generated system skills, machine installation IDs, or per-machine trust files. The tracked MCP configuration may name environment variables, but it must never contain the token values.
