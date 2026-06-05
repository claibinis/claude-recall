# Changelog

## 1.0.0

First tagged release. `claude-recall` indexes the `~/.claude/projects/` transcript
tree (cached by file mtime) and lets you search, read, resume, and manage sessions.

- **Search** — keyword search over prompts/names/projects; multi-word AND (or `--any`
  for OR); `--full-text` (`-f`) scans transcripts and shows match snippets.
- **Filter** — `--project` (by directory name), `--branch`, `--date`, and relative
  `--since`/`--until` (`7d`/`24h`/`2w` or `YYYY-MM-DD`).
- **Read** — `--show` pretty-prints a conversation (tool calls collapsed), with
  `--grep`, `--last N`, `--text-only`, and `--no-summary`.
- **Resume** — `--resume` prints the `cd … && claude --resume` command (`--exec` runs it).
- **Name** — `--set-name`/`--unname` label sessions in a sidecar (survives cleanup).
- **Analyze** — `--tokens`/`--context`/`--size` inline enrichments, `--detail`, and
  `--stats` (token/cost totals, cache-efficiency) which honors the active filters.
- **Manage** — `--remove`, `--clean` (by age), `--prune-empty`; never touches
  `history.jsonl`, so cleaned sessions stay searchable.
- **Sort/export** — `--sort date|recent|tokens|cost|size|messages`; `--export json|csv`.
