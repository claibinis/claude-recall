# Changelog

## 3.2.0

- **`claude-recall doctor`** — one command to check that everything's wired up:
  PATH symlink, Claude Code hooks, MCP registration, pricing file, and the metadata
  cache. Each line reports ✓/✗, and `doctor --fix` repairs what it safely can
  (re-link, re-install hooks, re-register MCP). Runs without building the index.
- **Color/title follow-through** (building on 3.1.0):
  - `--color NAME` filters the listing/search to one session color.
  - `--sort color` groups sessions by color (uncolored last).
  - A session's Claude Code title (`/name`) is now **searchable**, alongside its color.
  - `export` (csv/json) now includes `title` and `color` columns/fields.

## 3.1.0

- **Session colors in the listing.** claude-recall now reads the color you set in
  Claude Code with `/color` (stored per session as an `agent-color` line in the
  transcript) and shows each session in that exact color — the `★ name` and the
  session id are tinted to match what Claude Code shows on resume. Palette:
  `red, blue, green, yellow, purple, orange, pink, cyan` (`default`/unset = none).
  Coloring is automatic on a terminal, disabled when piped, and honors `NO_COLOR`.
- **Session titles.** A session's Claude Code title (`/name` / `/rename` →
  `custom_title`) is now surfaced as the row label when you haven't set a
  claude-recall name of your own.
- Internal: `parse_transcript` captures `color` + `custom_title`; `CACHE_VERSION`
  bumped to 6 (the cache rebuilds automatically on first run).

## 3.0.1

- Housekeeping: bump `__version__` to 3.0.1 and git-ignore a personal
  `slack-announcement.md` draft. No functional changes.

## 3.0.0

**Simpler to install, configure, and use.** The everyday surface is now ~7 commands;
everything else moved under `--help-all`.

### Added
- **`claude-recall setup`** — one command installs everything: symlinks onto your
  PATH, installs the Claude Code hooks, registers the MCP server, and offers to set
  up custom pricing. Idempotent; `setup --uninstall` reverses it. This is the new
  recommended install path.
- **Bare-word search** — `claude-recall deploy retry` now searches (no `-s` needed).
  Equivalent explicit form: `claude-recall search deploy retry`. `-s/--search` still
  works.

### Changed (breaking)
- **`unname ID` → `name ID --clear`** (the `name` command now also clears labels).
- **`prune-empty` → `clean --empty`** (clean gains an `--empty` flag for throwaway
  ≤1-prompt sessions; default `clean` is still age-based).
- **Concise `-h` lists only the core commands** (setup, search, show, resume, name,
  clean). `stats`, `export`, `remove`, `forget`, `install-hooks`, and `mcp` are still
  there — see `--help-all`.
- **Removed the `cc` shell wrappers** (`cc`, `cc.bash`, `cc.ps1`). The hooks installed
  by `setup`/`install-hooks` do the same auto-naming + exit-pruning, identically on
  every OS, with nothing to keep in sync. The `CC_*` environment variables are gone.

No change to indexing, search quality, cost/context analysis, or output formatting.

## 2.4.0

- **`claude-recall mcp` — MCP server (stdio).** claude-recall can now run as a
  [Model Context Protocol](https://modelcontextprotocol.io) server so Claude Code
  can recall your past sessions *mid-conversation*, calling tools itself instead of
  you running a search. Four tools over your existing index:
  - `search_sessions` — keyword (or `full_text`) search, returns date/project/snippet/resume
  - `read_session` — the verbatim conversation of one session (optionally `last N` / `grep`)
  - `recent_sessions` — what you were working on lately
  - `session_cost` — token + estimated-$ totals (uses your built-in or LiteLLM pricing)

  Register once: `claude mcp add claude-recall -- claude-recall mcp`. The protocol
  is spoken directly over stdin/stdout — **still zero dependencies**, nothing to
  `pip install`. The server rebuilds the (cached) index per call so recall stays
  fresh, and never crashes on a bad request: malformed input is ignored and tool
  errors are returned in-band.

## 2.3.2

- **Docs: positioning vs. native Claude Code.** Reviewed the Claude Code changelog
  (through 2.1.x) and confirmed nothing in claude-recall is obsoleted by native
  features. Adjacent features now exist — `/resume <name>` and the recent-prompt
  picker, the agent view / `claude agents`, `/stats` (date ranges + gamified usage),
  `/usage`, and context in the status line — but none search session *content*, do
  per-session cost with custom pricing, or clean up transcripts. The README now
  spells out this complementarity, and the `SessionStart` `sessionTitle` hook is
  verified current against the contract Claude Code formalized in 2.1.152. No
  behavior change.

## 2.3.1

- **`gen-pricing` gives a clear error on non-JSON responses** instead of a raw
  `JSONDecodeError` traceback. When `/model/info` returns an empty/HTML body (wrong
  base URL, an SSO/login page, or an insufficient key), it now reports the
  Content-Type, byte count, and first bytes received, with guidance. Also sends an
  `Accept: application/json` request header (some gateways return HTML without it).

## 2.3.0

- **Pricing file is now auto-discovered** — no env var required. claude-recall
  loads `pricing.json` from next to the script (or `~/.claude/pricing.json`) if
  present; `CLAUDE_RECALL_PRICING_FILE` still overrides. `scripts/gen-pricing`
  writes there by default (`--out` to change, `--out -` for stdout). The file is
  git-ignored, and `_`-prefixed keys (e.g. `_meta` provenance) are ignored on load.
- **`gen-pricing --discount PCT`** — bake a negotiated discount into the generated
  rates (e.g. `--discount 25` for 25% off the gateway's published prices). Token
  limits (`max_input`/`max_output`) are not discounted.

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
