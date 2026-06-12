# Changelog

## 2.2.0

- **Multi-line listing by default** — each session row now shows up to two
  prompts: the **opening** ask plus the **most recent** one (bookends), so a row
  conveys what a session was about *and* where it ended, instead of a single
  truncated line. Single-prompt sessions stay one line.
  - `--lines N` sets how many prompts per row (default 2); `CLAUDE_RECALL_LINES`
    sets a persistent default; `-v` shows more.
  - Continuation lines reuse the same substantive-prompt filter, so compaction
    boilerplate ("This session is being continued…") and command output no
    longer appear. Search results stay compact (the `↳` match line only).

## 2.1.0

- **`install-hooks`** — wire claude-recall into Claude Code's own hooks as a
  config-driven alternative to the `cc` wrapper, with one command:
  - `SessionStart` auto-names each session `folder@branch` (via `sessionTitle`).
  - `SessionEnd` prunes the just-ended session if it's throwaway (≤1 prompt).

  The installer is idempotent, preserves any existing hooks/settings, backs up
  `settings.json` first, and `--uninstall`/`--dry-run` are supported. Hooks are
  non-interactive, so naming is automatic (refine with `/rename` or `name`) and
  cleanup is a policy rather than a prompt — but no wrapper, and identical on
  every OS. The underlying `hook session-start`/`hook session-end` commands read
  the hook event on stdin (internal; invoked by the installed hooks).

## 2.0.2

- **Command output is no longer indexed as prompts** — captured `! ` command
  output and bash tool I/O (`<local-command-stdout>`, `<bash-input>`,
  `<bash-stdout>`/`-stderr>`) were being stored as user "prompts", which is why
  rows showed things like a `cc` exit banner (`Catch you later!`) or
  `==> Auto-updating Homebrew…`. These are now dropped at parse time, so prompt
  counts and labels reflect real conversation only. (Cache rebuilds automatically.)
- **Better fallback labels** — a session with no substantive user prompt now falls
  back to the first thing Claude said; if there's genuinely nothing (e.g. an
  immediate `/exit`), the label is simply blank instead of `(no prompt)`.

## 2.0.1

- **Smarter listing labels** — the prompt shown for each session is now the most
  recent *substantive* one, skipping farewells/acks ("Goodbye!", "Catch you later",
  "thanks", …), slash-commands (`/exit`, `/clear`), and placeholder turns like
  `(no content)`. Sessions with nothing but trivia show `(no prompt)` instead of
  echoing the goodbye.

## 2.0.0

**Breaking:** the nine actions are now **git-style subcommands** instead of flags.
Listing/search stays the default (no command), so `claude-recall -s "deploy" --tokens`
is unchanged — but the action flags moved:

| Old | New |
|-----|-----|
| `--show ID [--grep/--last/--no-summary/--text-only]` | `show ID …` |
| `--resume ID [--exec]` | `resume ID …` |
| `--stats` | `stats` |
| `--export json\|csv` | `export json\|csv` |
| `--set-name ID NAME` / `--unname ID` | `name ID NAME` / `unname ID` |
| `--remove ID` | `remove ID` |
| `--clean [--older-than N]` | `clean …` |
| `--prune-empty` | `prune-empty` |

Each command has its own `-h` (`claude-recall show -h`). Filters/sort/display flags
still apply to `stats` and `export`. The `cc` wrappers now call `claude-recall clean`.

### Added

- **Recoverable-only by default** — history-only "ghost" sessions (transcript deleted,
  not openable) are hidden from the listing and search. Use `--all`/`--include-deleted`
  to bring them back.
- **`forget`** — new command that purges history-only sessions from Claude Code's
  `history.jsonl` (and drops their name labels). Opt-in, confirmed, `--dry-run`-able;
  the only path that edits `history.jsonl`.
- **`-y`/`--yes`** on `remove`/`clean`/`prune-empty`/`forget` to skip the confirmation
  prompt — enables unattended use, e.g. a `SessionEnd` hook (`claude-recall prune-empty -y`)
  as a config-driven alternative to the `cc` exit prompt.

## 1.1.0 — 2026-06-05

- **Custom model pricing** — `scripts/gen-pricing` generates a pricing file from any
  LiteLLM gateway's standard `/model/info` endpoint (credentials supplied via
  `LITELLM_BASE_URL`/`LITELLM_API_KEY`). Point claude-recall at it with
  `CLAUDE_RECALL_PRICING_FILE` to override the built-in default rates; unset, defaults
  are unchanged. Model lookup is now longest-match, so `claude-opus-4-8` beats a generic
  `claude-opus-4` entry.
- **Two-tier help** — concise `-h`/`--help` for everyday flags; `--help-all` prints the
  full option reference.

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
