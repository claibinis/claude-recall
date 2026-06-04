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
- Timestamps: transcripts use ISO-8601 strings, `history.jsonl` uses epoch ms — `to_ms()` normalizes both to epoch ms. `clean_display()` turns `<command-name>/foo</command-name>` wrappers and tag noise into readable prompts.
- Cost estimation: `estimate_cost()` applies per-model pricing from the `PRICING` dict by substring-matching the model name (falls back to `default`/Opus rates).
- Display: plain column-formatted terminal output, **no ANSI colors** (only `cc` colorizes). `--tokens`/`--size`/`--context` are composable inline enrichments; `--detail` switches to an expanded per-session view that includes a ready-to-run resume command.
- Actions (mutually exclusive, return early before the listing path): `--resume` (print `cd <dir> && claude --resume <id>`), `--remove` (single session by ID prefix), `--clean` (bulk by age), `--stats`, `--export` (json/csv).
- Resume: `resume_command()` builds the shell command to resume a session. Claude Code resume is project-scoped, so it prepends `cd <cwd> &&` unless `os.getcwd()` already matches the session's directory.

**Core invariant:** every destructive path (`--remove`, `--clean`, `cc`'s discard) deletes only transcript files and their subagent dirs — it **never** touches `history.jsonl` (and is harmless to the cache, which self-heals on the next run). Removed sessions still appear in search results, marked `-` instead of `+`. Preserve this when modifying cleanup logic.

**`cc`** (zsh) — thin wrapper:
- Prompts for session name → passes `-n` to `claude`
- On exit prompts to keep/discard/clean. Discard finds the just-ended transcript via `find ... -newer /tmp/.cc_session_start` (a marker file `touch`ed at launch)
- Passthrough: skips the name prompt when `-n`/`--name` is present, skips both prompts for `-p`/`--print`
- Configurable via `CC_SKIP_NAME`, `CC_SKIP_EXIT`, `CC_AUTO_CLEAN_DAYS` env vars

## Key Data Paths

The tool reads from the Claude Code data directory (configurable via `CLAUDE_DIR` env var, defaults to `~/.claude/`):
- `projects/<path-encoded-dir>/<session-id>.jsonl` — full transcripts; **the primary index source**. Each transcript records `cwd`, `gitBranch`, ISO timestamps, user messages, model, and per-turn `usage`.
- `.claude-recall-cache.json` — the tool's own metadata cache (safe to delete; rebuilt on next run).
- `history.jsonl` — one line per user prompt; read only to surface deleted-transcript sessions.

## Pricing

Model pricing lives in the `PRICING` dict near the top of `claude-recall`. Adjust rates there when pricing changes.
