# Claude Code Plugins & Skills

## Marketplace Plugins

Install with: `claude plugin add <url>`

| Plugin | Description | Install |
|--------|-------------|---------|
| caveman | Ultra-compressed communication (~75% token savings) | `claude plugin add https://github.com/JuliusBrussee/caveman` |
| playwright-skill | Browser automation with Playwright | `claude plugin add https://github.com/lackeyjb/playwright-skill` |
| vercel-plugin | Vercel platform integration | `claude plugin add https://github.com/vercel/vercel-plugin` |

## Local Skills (`~/.claude/skills/`)

| Skill | Trigger | Description |
|-------|---------|-------------|
| graphify | `/graphify` | Any input to knowledge graph with community detection |
| tdd | `/tdd` | Test-Driven Development red/green/refactor cycles |

## Custom Commands (`~/.claude/commands/`)

Security testing commands (copy from dotfiles `.claude/commands/`):

- `api-keys` — Scan for exposed API keys and secrets
- `bug-bounty-hunter` — Bug bounty hunting advisor
- `ctf-assistant` — CTF competition helper
- `pentest-advisor` — Penetration testing advisor
- `sqli-test` — SQL injection test payloads
- `webshell-detect` — Web shell detection
- `wordlist` — SecLists wordlist access
- `xss-test` — XSS payload generation

## Setup on New Machine

```bash
# 1. Symlink or copy .claude config
cp -r dotfiles/.claude/CLAUDE.md ~/.claude/
cp -r dotfiles/.claude/RTK.md ~/.claude/
cp -r dotfiles/.claude/settings.json ~/.claude/
cp -r dotfiles/.claude/skills/ ~/.claude/skills/
cp -r dotfiles/.claude/commands/ ~/.claude/commands/

# 2. Install marketplace plugins
claude plugin add https://github.com/JuliusBrussee/caveman
claude plugin add https://github.com/lackeyjb/playwright-skill
claude plugin add https://github.com/vercel/vercel-plugin
```
