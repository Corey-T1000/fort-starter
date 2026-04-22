# Toolbox

> Inventory of tools, runtimes, and services the agent can route to. Update as your stack evolves. CLAUDE.base.md points the agent here for the full tool catalog.

## Languages / runtimes

- (e.g., Node 22, Python 3.12, Go 1.23, Rust stable)
-
-

## Cloud / infra

- Hosting: (e.g., Vercel, Fly.io, self-hosted on a homelab)
- Databases: (e.g., Postgres on Neon, SQLite local, Dolt for shared state)
- Storage: (e.g., R2, S3)
- DNS / domains:

## MCP servers configured

- (e.g., `linear-server` — issue tracking)
- (e.g., `mempalace` — semantic memory)
- (e.g., `youtube-transcript` — YouTube only, never scrape)

## Browser / OS / shell preferences

- OS:
- Shell: (e.g., zsh, fish)
- Terminal: (e.g., Ghostty, iTerm2)
- Browser: (e.g., Arc, Chrome, Zen)
- Editor: (e.g., Neovim, VS Code, Cursor)

## Custom CLIs in my $PATH

- (e.g., `fort-status`, `fort-notify`, `fort-stream`)
- (e.g., personal scripts in `~/bin/`)
-

## Default routing rules

- Web fetch / scraping → (e.g., agent-browser headless)
- Untrusted code → (e.g., sandbox, container)
- Long-running tasks → (e.g., background agents)
- Notifications → (e.g., `fort-notify`, ntfy push)
