# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

`claude-recall` is a CLI tool for searching, analyzing, and managing Claude Code session history stored in `~/.claude/`. It provides keyword search, token usage/cost reporting, context window analysis, and transcript cleanup.

Two executables:
- `claude-recall` — Python 3.6+ script (no external dependencies). The main tool.
- `cc` — zsh wrapper around `claude` that adds session naming prompts and exit cleanup.

## Running

```bash
# Run directly
./claude-recall

# Run with search
./claude-recall -s "keyword"

# Run the wrapper
./cc
```

No build step, no package install, no test suite. These are standalone scripts.

## Architecture

**`claude-recall`** (Python) — single-file CLI with this structure:
- **Index building (`build_index`)** — the source of truth is the `projects/` transcript tree, *not* a static file. It walks every `*.jsonl`, and `parse_transcript()` does a **single pass** per file extracting everything that gets cached: project dir (`cwd`), git branch, first/last timestamps, user prompts, model, and token totals. Subagent transcripts are excluded from the index but `get_session_dir_size()` still counts them toward per-session size totals.
- **Caching** — parsed metadata is cached in `~/.claude/.claude-recall-cache.json`, keyed by transcript path with its `mtime`+`size`. On each run, unchanged files reuse cached metadata; only new/altered files are re-parsed. The cache is rewritten only when something changed (atomically, via a `.tmp` rename). Bump `CACHE_VERSION` whenever the cached `meta` shape changes, to force a rebuild. Because usage lives in the cached session dict, no consumer re-reads transcripts — `--tokens`/`--context`/`--sort cost`/export all read in-memory fields.
- **`history.jsonl` is supplementary only** — `merge_history_only()` adds sessions whose transcript was deleted (so they still show, marked `-`). The live index does not depend on it.
- Timestamps: transcripts use ISO-8601 strings, `history.jsonl` uses epoch ms — `to_ms()` normalizes both to epoch ms. `clean_display()` turns `<command-name>/foo</command-name>` wrappers, tag noise, and ANSI escape codes into readable prompts.
- Cost estimation: `estimate_cost()` applies per-model pricing from the `PRICING` dict by substring-matching the model name (falls back to `default`/Opus rates). `cache_reuse_ratio()` derives the cache-hit fraction (reads / all input tokens) shown in `--stats` and `--detail`.
- Context warning: `context_warns()` flags a session's peak context against the model's window from `CONTEXT_LIMITS` (Opus/Haiku 200K, Sonnet 1M) at `CONTEXT_WARN_RATIO` (default 0.9, override via `CLAUDE_RECALL_CTX_WARN`) — not a hardcoded number.
- Search: `parse_terms()` splits the query into whitespace-separated terms; `terms_match()` is AND by default / OR with `--any`. Names and project are searchable alongside prompts. `search_transcripts()` (full-text, `-f`) returns `{id: snippet}`; `make_snippet()`/`first_snippet()` build the `↳`-prefixed match previews shown under listing rows.
- Help: two-tier — `add_help=False`, with a hand-written concise `-h`/`--help` (`print_short_help()`/`SHORT_HELP`) and `--help-all` that prints argparse's full `parser.print_help()`.
- Display: plain column-formatted terminal output, **no ANSI colors** (only `cc` colorizes; `--show`'s `--grep` marks hits with `« »`). `--tokens`/`--size`/`--context` are composable inline enrichments; `--detail` switches to an expanded per-session view; the listing row shows `proj@branch` for non-default branches and a `★ name` label when assigned.
- Actions (mutually exclusive, return early before the listing path): `--show` (pretty-print a conversation; `cmd_show` collects turns first so `--last N` can slice the tail, coalescing consecutive assistant messages into one turn so tool-only lines don't count; `--grep` filters/highlights, `--no-summary` drops `isCompactSummary` turns, `--text-only` drops prose-less turns, `assistant_summary()` + `format_tools()` collapse tool calls with `×N` repeat counts), `--resume` (print, or run with `--exec`), `--set-name`/`--unname` (sidecar names), `--remove`, `--clean` (by age), `--prune-empty` (≤1-prompt junk), `--stats`, `--export` (json/csv). `_resolve_or_exit()` is the shared ID-prefix resolver.
- Resume: `resume_command()` builds the shell command to resume a session. Claude Code resume is project-scoped, so it prepends `cd <cwd> &&` unless `os.getcwd()` already matches the session's directory; `--exec` runs it via `subprocess.call(..., shell=True)`.
- Filters: `filter_sessions()` applies search + `--project` (directory **basename**, not full path) + `--branch` (git branch substring) + `--date` + `--since`/`--until` (relative `7d`/`24h`/`2w` or `YYYY-MM-DD` via `parse_when()`, on last activity). Both the listing and `--stats` run through it, so `--stats` reports totals for whatever subset the filters select (`filters_scope()` labels the header).

**Core invariant:** every destructive path (`--remove`, `--clean`, `--prune-empty`, `cc`'s discard) deletes only transcript files and their subagent dirs — it **never** touches `history.jsonl` (and is harmless to the cache, which self-heals on the next run). Removed sessions still appear in search results, marked `-` instead of `+`. User-assigned names live in `.claude-recall-names.json` and survive transcript deletion. Preserve this when modifying cleanup logic.

**`cc`** (zsh) — thin wrapper:
- Prompts for session name → passes `-n` to `claude`
- On exit prompts to keep/discard/clean. Discard finds the just-ended transcript via `find ... -newer /tmp/.cc_session_start` (a marker file `touch`ed at launch)
- Passthrough: skips the name prompt when `-n`/`--name` is present, skips both prompts for `-p`/`--print`
- Configurable via `CC_SKIP_NAME`, `CC_SKIP_EXIT`, `CC_AUTO_CLEAN_DAYS` env vars
- Ported to `cc.bash` (bash; uses a `/tmp/.cc_session_start` marker like `cc`) and `cc.ps1` (Windows PowerShell; uses a captured `$start` time + `LastWriteTime` instead of a marker file). Keep the three behaviorally in sync when changing wrapper logic. `claude-recall.cmd` is a Windows launcher that runs the Python script via `py`/`python`.

## Key Data Paths

The tool reads from the Claude Code data directory (configurable via `CLAUDE_DIR` env var, defaults to `~/.claude/`):
- `projects/<path-encoded-dir>/<session-id>.jsonl` — full transcripts; **the primary index source**. Each transcript records `cwd`, `gitBranch`, ISO timestamps, user messages, model, and per-turn `usage`.
- `.claude-recall-cache.json` — the tool's own metadata cache (safe to delete; rebuilt on next run).
- `.claude-recall-names.json` — sidecar map of `{session_id: name}` for `--set-name` (safe to delete; just drops the labels).
- `history.jsonl` — one line per user prompt; read only to surface deleted-transcript sessions.

## Pricing

Model pricing lives in the `PRICING` dict near the top of `claude-recall`. Adjust rates there when pricing changes.
