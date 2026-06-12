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
- **Index building (`build_index`)** — the source of truth is the `projects/` transcript tree, *not* a static file. It walks every `*.jsonl`, and `parse_transcript()` does a **single pass** per file extracting everything that gets cached: project dir (`cwd`), git branch, first/last timestamps, user prompts, the first assistant text (`first_assistant`, a fallback label), model, and token totals. Subagent transcripts are excluded from the index but `get_session_dir_size()` still counts them toward per-session size totals.
- **Caching** — parsed metadata is cached in `~/.claude/.claude-recall-cache.json`, keyed by transcript path with its `mtime`+`size`. On each run, unchanged files reuse cached metadata; only new/altered files are re-parsed. The cache is rewritten only when something changed (atomically, via a `.tmp` rename). Bump `CACHE_VERSION` whenever the cached `meta` shape changes, to force a rebuild. Because usage lives in the cached session dict, no consumer re-reads transcripts — `--tokens`/`--context`/`--sort cost`/export all read in-memory fields.
- **`history.jsonl` is supplementary only** — `merge_history_only()` adds sessions whose transcript was deleted (history-only "ghosts", marked `-`). The live index does not depend on it. These ghosts are **hidden by default** (`filter_sessions()` drops any session not in `transcripts` unless `--all`/`--include-deleted`), since they can't be `show`n or `resume`d. The `forget` command can purge them from `history.jsonl` entirely (see the core-invariant note).
- Timestamps: transcripts use ISO-8601 strings, `history.jsonl` uses epoch ms — `to_ms()` normalizes both to epoch ms. `clean_display()` turns `<command-name>/foo</command-name>` wrappers, tag noise, and ANSI escape codes into readable prompts — and returns `""` for captured command I/O (`<local-command-stdout>`, `<bash-input>`, `<bash-stdout>`/`-stderr>`) so command output is never indexed as a "prompt".
- Cost estimation: `estimate_cost()` applies per-model pricing from the `PRICING` dict via `_best_match()` (longest matching key wins, so `claude-opus-4-8` beats a generic `claude-opus-4`; falls back to `default`/Opus rates). `cache_reuse_ratio()` derives the cache-hit fraction (reads / all input tokens) shown in `stats` and `--detail`.
- Pricing overrides: `_load_pricing_overrides()` (called once at import) merges per-model rates over `PRICING`/`CONTEXT_LIMITS`; unset → built-in defaults unchanged. `_pricing_file()` resolves the source: `CLAUDE_RECALL_PRICING_FILE` if set, else an auto-discovered `pricing.json` next to the script (where the command lives), else `CLAUDE_DIR/pricing.json` — so no env var is needed. Keys starting with `_` (e.g. `_meta`) are skipped. Generate the file for any LiteLLM gateway with `scripts/gen-pricing` (reads `LITELLM_BASE_URL`/`LITELLM_API_KEY`, hits `/model/info`; `--discount PCT` bakes in a negotiated discount, `--out` defaults to the co-located `pricing.json`, which is git-ignored).
- Context warning: `context_warns()` flags a session's peak context against the model's window from `CONTEXT_LIMITS` (Opus/Haiku 200K, Sonnet 1M; overridable per model via the pricing file's `max_input`) at `CONTEXT_WARN_RATIO` (default 0.9, override via `CLAUDE_RECALL_CTX_WARN`) — not a hardcoded number.
- Search: `parse_terms()` splits the query into whitespace-separated terms; `terms_match()` is AND by default / OR with `--any`. Names and project are searchable alongside prompts. `search_transcripts()` (full-text, `-f`) returns `{id: snippet}`; `make_snippet()`/`first_snippet()` build the `↳`-prefixed match previews shown under listing rows.
- CLI shape: **git-style subcommands** built in `build_parser()`. Three shared parent parsers (`add_help=False`) — `filters` (search/project/branch/date/since/until), `display` (tokens/context/size), `ordering` (limit/reverse/sort) — are mixed into the top-level parser (the default *list* path) and re-used by the subparsers that need them (`stats` takes `filters`; `export` takes all three). `parser.add_subparsers(dest="command")` registers the ten actions: `show`, `resume`, `stats`, `export`, `name`, `unname`, `remove`, `clean`, `prune-empty`, `forget`. No subcommand → listing. `main()` dispatches on `args.command`; each action returns early before the listing path. ID/format are positionals on the subparsers (`args.id`, `args.name`, `args.format`). Subcommands get native `-h` for free; the top-level keeps a hand-written concise `-h`/`--help` (`print_short_help()`/`SHORT_HELP`) plus `--help-all` (argparse's `parser.print_help()`, which lists the subcommands).
- Display: plain column-formatted terminal output, **no ANSI colors** (only `cc` colorizes; `show`'s `--grep` marks hits with `« »`). `--tokens`/`--size`/`--context` are composable inline enrichments; `--detail` switches to an expanded per-session view; the listing row shows `proj@branch` for non-default branches and a `★ name` label when assigned. Each row shows up to `--lines` prompts (default 2, or `CLAUDE_RECALL_LINES`; `-v` bumps it) from `session_prompts()` — the **opening** substantive prompt inline plus the **most recent** ones as indented continuation lines (bookends for long sessions). `is_trivial_prompt()` skips farewells/acks (`TRIVIAL_PROMPTS`), slash-commands, bracketed placeholders like `(no content)`, and compaction boilerplate; a session with no real prompt falls back to `first_assistant`, else blank. When a search snippet is shown the continuation lines are suppressed (the `↳` match line stands in).
- Action handlers: `show` (pretty-print a conversation; `cmd_show` collects turns first so `--last N` can slice the tail, coalescing consecutive assistant messages into one turn so tool-only lines don't count; `--grep` filters/highlights, `--no-summary` drops `isCompactSummary` turns, `--text-only` drops prose-less turns, `assistant_summary()` + `format_tools()` collapse tool calls with `×N` repeat counts), `resume` (print, or run with `--exec`), `name`/`unname` (sidecar names), `remove`, `clean` (by age), `prune-empty` (≤1-prompt junk), `forget` (purge history-only ghosts), `stats`, `export` (csv/json positional). The deletion commands (`remove`/`clean`/`prune-empty`/`forget`) share a `confirm()` helper; `-y`/`--yes` auto-confirms for unattended/hook use. `_resolve_or_exit()` is the shared ID-prefix resolver.
- Hooks (config alternative to the `cc` wrapper): `install-hooks` merges `SessionStart`/`SessionEnd` entries into `settings.json` (idempotent via `_group_is_ours()`, backs up to `settings.json.bak`, atomic `.tmp` write, `--uninstall`/`--dry-run`). The installed hooks call `claude-recall hook session-start|session-end` (the `hook` subparser is `SUPPRESS`-hidden). `cmd_hook_session_start()` reads the event JSON on stdin and prints `hookSpecificOutput.sessionTitle` = `folder@branch` (only for `startup`/`resume` sources); `cmd_hook_session_end()` parses the named `transcript_path` and unlinks it if `msg_count <= 1`. Both **swallow all errors and exit 0** so a hook never disrupts a session, and **`hook`/`install-hooks` dispatch before `build_index()`** (hooks must be fast; the installer doesn't need the index).
- Resume: `resume_command()` builds the shell command to resume a session. Claude Code resume is project-scoped, so it prepends `cd <cwd> &&` unless `os.getcwd()` already matches the session's directory; `--exec` runs it via `subprocess.call(..., shell=True)`.
- Filters: `filter_sessions()` first drops history-only ghosts unless `--all`, then applies search + `--project` (directory **basename**, not full path) + `--branch` (git branch substring) + `--date` + `--since`/`--until` (relative `7d`/`24h`/`2w` or `YYYY-MM-DD` via `parse_when()`, on last activity). Both the listing and `stats` run through it, so `stats` reports totals for whatever subset the filters select (`filters_scope()` labels the header).

**Core invariant:** every *transcript* cleanup path (`remove`, `clean`, `prune-empty`, `cc`'s discard) deletes only transcript files and their subagent dirs — it **never** touches `history.jsonl` (and is harmless to the cache, which self-heals on the next run). Removed sessions become history-only ghosts (still in `history.jsonl`, surfaced with `--all`, marked `-`). User-assigned names live in `.claude-recall-names.json` and survive transcript deletion. Preserve this when modifying cleanup logic.

**The one exception:** `cmd_forget()` is the *only* path that edits `history.jsonl` (Claude Code's own file — the source `/resume` reads for names). It rewrites the file to drop lines for already-deleted (non-recoverable) sessions and prunes their name-sidecar entries. It is opt-in, confirmed (or `-y`), `--dry-run`-able, and never runs automatically; it leaves transcript-backed sessions untouched. Keep it that way — don't fold history.jsonl edits into the normal cleanup paths.

**`cc`** (zsh) — thin wrapper (optional; `install-hooks` is the config-driven, wrapper-free alternative — it covers naming + exit-cleanup non-interactively):
- Prompts for session name → passes `-n` to `claude`
- On exit prompts to keep/discard/clean. Discard finds the just-ended transcript via `find ... -newer /tmp/.cc_session_start` (a marker file `touch`ed at launch)
- Passthrough: skips the name prompt when `-n`/`--name` is present, skips both prompts for `-p`/`--print`
- Configurable via `CC_SKIP_NAME`, `CC_SKIP_EXIT`, `CC_AUTO_CLEAN_DAYS` env vars
- Ported to `cc.bash` (bash; uses a `/tmp/.cc_session_start` marker like `cc`) and `cc.ps1` (Windows PowerShell; uses a captured `$start` time + `LastWriteTime` instead of a marker file). Keep the three behaviorally in sync when changing wrapper logic. `claude-recall.cmd` is a Windows launcher that runs the Python script via `py`/`python`.

## Key Data Paths

The tool reads from the Claude Code data directory (configurable via `CLAUDE_DIR` env var, defaults to `~/.claude/`):
- `projects/<path-encoded-dir>/<session-id>.jsonl` — full transcripts; **the primary index source**. Each transcript records `cwd`, `gitBranch`, ISO timestamps, user messages, model, and per-turn `usage`.
- `.claude-recall-cache.json` — the tool's own metadata cache (safe to delete; rebuilt on next run).
- `.claude-recall-names.json` — sidecar map of `{session_id: name}` for the `name` command (safe to delete; just drops the labels).
- `history.jsonl` — one line per user prompt; read only to surface deleted-transcript sessions.

## Pricing

Model pricing lives in the `PRICING` dict near the top of `claude-recall`. Adjust rates there when pricing changes, **or** generate a pricing file from a LiteLLM gateway and point `CLAUDE_RECALL_PRICING_FILE` at it:

```bash
export LITELLM_BASE_URL=https://your-litellm-gateway.example.com
export LITELLM_API_KEY=sk-...        # LITELLM_INSECURE=1 for a private-CA gateway
./scripts/gen-pricing > ~/.claude/pricing.json
export CLAUDE_RECALL_PRICING_FILE=~/.claude/pricing.json
```

`scripts/gen-pricing` converts the gateway's per-token rates to per-1M (matching the `PRICING` dict) and includes cache costs + context limits. The file overrides defaults when set; it's plain JSON and can be hand-edited.
