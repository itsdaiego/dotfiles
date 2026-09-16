# Global agent rules

- Never run `git push` or otherwise publish commits, branches, tags, releases, deployments, or other remote changes unless the user explicitly asks to push/publish that specific change after they have had an opportunity to review it. A prior request to push a different commit does not authorize later pushes.
- Never execute an AWS CLI (`aws`) command. Do not bypass this restriction through a script, wrapper, alias, subshell, or another command. Provide the command for the user to review and run manually.
- Always ask the user for confirmation immediately before a recursive forced deletion, such as `rm -rf <folder>`. Execute only the exact command that the user confirms. Block the command when confirmation is unavailable or denied.
