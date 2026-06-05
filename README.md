# claude-recall

> Total recall for your Claude Code conversations.

Search, analyze, and manage your Claude Code session history. Find that conversation you had three weeks ago, see how many tokens you've burned, and clean up old transcripts eating your disk.

## Why?

Claude Code's built-in `/resume` only searches by session name or exact ID. If you didn't name a session (and let's be honest — you didn't), it's gone into the void. `claude-recall` indexes everything in `~/.claude/` and lets you find sessions by keyword, project, date, token usage, or disk size.

## Installation

```bash
# Clone it
git clone https://github.com/claibinis/claude-recall.git
cd claude-recall

# Option A: symlink both tools to your PATH
ln -s "$(pwd)/claude-recall" ~/bin/claude-recall
ln -s "$(pwd)/cc" ~/bin/cc

# Option B: copy them
cp claude-recall cc ~/bin/

# Option C: just run directly
./claude-recall
```

**Requirements:** Python 3.6+ (no external dependencies). The session wrapper ships in three flavors — pick the one for your shell: `cc` (zsh), `cc.bash` (bash), or `cc.ps1` (Windows PowerShell).

### Windows

`claude-recall` is plain Python, so it runs on Windows too — invoke it as `python claude-recall ...`, or put this folder on your `PATH` and use the included `claude-recall.cmd` launcher to just type `claude-recall ...`. For the session wrapper, use `cc.ps1` (e.g. add `function cc { & "C:\path\to\cc.ps1" @args }` to your PowerShell `$PROFILE`).

## Usage

### List all sessions

```bash
claude-recall
```

```
Claude Code Sessions (83 of 83)  [+ = transcript on disk, - = history only]

  2026-06-02 09:44  [cf21fedb] +  (  4 msgs)  laibinis          find sessions
  2026-06-01 12:48  [9e29a7a6] +  ( 24 msgs)  laibinis          how long could one live on...
  2026-05-28 07:23  [654f5fb5] +  ( 50 msgs)  laibinis          why does the build fail when...
  ...
```

The `+`/`-` indicator shows whether the full transcript file is still on disk or only the message index remains.

### Search by keyword(s)

```bash
claude-recall -s "deployment"
claude-recall -s "deploy retry timeout"     # all three words must appear (AND)
claude-recall -s "auth login signup" --any  # any of the words (OR)
```

A multi-word query is **AND by default** — every term must appear (in the prompts, the session name, or the project). Use `--any` for OR. Searches show a `↳` snippet of the match under each result.

Add `-f` for full-text search through transcript files (slower, but catches assistant responses and tool output too — and the snippet comes from the matching line):

```bash
claude-recall -s "playwright tools" -f
```

### Read a session

Found the right session but want to *read* it without resuming? `--show` pretty-prints the conversation, collapsing tool noise:

```bash
claude-recall --show cf21fedb
claude-recall --show cf21fedb --grep "timeout"   # only turns mentioning "timeout", highlighted
claude-recall --show cf21fedb --last 10          # just the final 10 turns
claude-recall --show cf21fedb --no-summary       # skip auto-generated compaction recaps
claude-recall --show cf21fedb --text-only        # drop tool-only turns (prose only)
```

For a long session, `--last N` ("what was I doing at the end of this?") and `--grep` are the way in — a full dump of an 800-prompt session is tens of thousands of lines. Consecutive assistant messages (prose + their tool calls) are merged into one turn, and repeated tools collapse to `Bash ×3`. `--no-summary` hides the "session continued from a previous conversation" recap turns; `--text-only` drops any turn with no prose.

### Filter by project, branch, or time

```bash
claude-recall --project ete-tools     # matches the directory name (not the whole path)
claude-recall --branch fix-auth       # git branch substring
claude-recall --since 7d              # active in the last 7 days (also 24h, 2w, or 2026-04-01)
claude-recall --until 2026-05-01      # active before a date
claude-recall --date 2026-04          # started in a given month/day
```

Non-default branches show inline as `project@branch` in the listing.

### Token usage and cost

```bash
# Show cost estimate inline
claude-recall --tokens -n 10

# Detailed breakdown per session
claude-recall --tokens --detail -n 5

# Sort by cost (most expensive first)
claude-recall --tokens --sort cost
```

```
Detailed Token Usage:

  Session: 654f5fb5  |  Model: claude-opus-4-6
  Input:                     264
  Output:                 43.2K
  Cache write:           733.3K
  Cache read:              5.2M
  Peak context:            5.9M
  API turns:                 50
  Est. cost:             $10.98
```

### Peak context window

See which sessions pushed the context limit:

```bash
claude-recall --context -n 10
```

Sessions exceeding 180K tokens are flagged with ⚠.

### Disk usage

```bash
# Show file sizes inline
claude-recall --size

# Sort by size (largest first)
claude-recall --size --sort size
```

### Resume a session

Forgot where a session was and how to get back into it? `--resume` prints the exact command — including the `cd` into the right working directory, since Claude Code's resume is project-scoped:

```bash
claude-recall --resume d817ab64
```

```
  Session:  d817ab64-b828-405f-86fe-3ba0397a0c50
  Date:     2026-05-31 17:52
  Project:  cruisesort  (main)
  Dir:      /Users/you/github/cruisesort

  Resume with:

    cd /Users/you/github/cruisesort && claude --resume d817ab64-b828-405f-86fe-3ba0397a0c50
```

If you're already in the session's directory, the `cd` is omitted. The 8-char prefix shown in the listing is all you need. Add `--exec` to skip the copy-paste and jump straight back in:

```bash
claude-recall --resume d817ab64 --exec
```

### Name a session

Most sessions are unnamed, which is the whole reason they're hard to find. Give one a name after the fact — it's stored separately and never touches the transcript:

```bash
claude-recall --set-name d817ab64 "gpu capacity planning"
claude-recall --unname d817ab64
```

Named sessions show a `★` in the listing and are matched by search. The name survives even if you later delete the transcript.

### Remove a specific session

```bash
claude-recall --remove cf21fedb              # by 8-char prefix
claude-recall --remove cf21fedb --dry-run    # preview first
```

```
  Session:  cf21fedb-e69d-40d0-a2c4-077ad9feb67f
  Date:     2026-06-02 09:44
  Project:  laibinis
  Messages: 12
  Summary:  find sessions
  Disk:     860.3KB

  Remove this session's transcript? [y/N]
```

Only deletes the transcript file — the history index entry is preserved so the session still appears in search results (marked `-`).

### Bulk cleanup old transcripts

Preview what would be deleted:

```bash
claude-recall --clean --older-than 60 --dry-run
```

Actually clean up (interactive confirmation):

```bash
claude-recall --clean --older-than 60
```

Cleanup **never** touches `history.jsonl` — your session index is preserved so keyword search still works. Only transcript files (the large JSONL conversation logs) are removed.

To clear out throwaway sessions (a stray `/exit`, a one-line question) rather than old ones:

```bash
claude-recall --prune-empty --dry-run
claude-recall --prune-empty
```

### Statistics

```bash
claude-recall --stats                          # everything
claude-recall --stats --project cruisesort     # just one project
claude-recall --stats --since 30d              # just the last 30 days
claude-recall --stats -s "deploy"              # just sessions matching a search
```

`--stats` honors the same search and filters as the listing, so you can answer "how much did I spend on _project X_?" or "what did this month cost?" The header notes the active scope.

```
Sessions in history:    83
Transcripts on disk:    27
Total prompts:          2238
Disk usage:             61.0MB
Date range:             2026-03-02 13:27 → 2026-06-02 09:44

Token Usage (transcripts on disk):
  Input:                2.1K
  Output:               512.3K
  Cache write:          8.2M
  Cache read:           62.4M
  Estimated total cost: $147.23

Cache efficiency:
  Reuse ratio:          88%   (reads / all input tokens)
  Low-reuse sessions (paid to write cache, reused little):
    [a1b2c3d4] big-refactor       write   2.1M  read 412.0K  reuse  16%

By project:
    44  laibinis
    14  Few-Word
     7  ete-tools
    ...
```

The **cache efficiency** block shows how much of your input was served from cache (cheap) versus freshly written (expensive), and flags sessions that paid to write a lot of cache they barely reused.

### Export

```bash
claude-recall --export json > sessions.json
claude-recall --export csv > sessions.csv
claude-recall --export json --tokens   # includes token data
```

### Composable flags

`--tokens`, `--size`, and `--context` are **display modifiers** — use any combination with any filter:

```bash
# Everything at once
claude-recall --tokens --size --context -n 5

# Search + enrichments
claude-recall -s "auth" --project login --tokens --size --sort cost

# Sort by cost, show disk usage too
claude-recall --sort cost --tokens --size -n 10

# Detailed per-session breakdown (instead of inline)
claude-recall --detail --project ete -n 3
```

## All options

`claude-recall -h` prints a concise, grouped summary; `claude-recall --help-all` prints the full option list below.

| Flag | Description | Composable |
|------|-------------|:---:|
| **Filters** |
| `-s`, `--search` | Search by keyword(s); space-separated = AND | |
| `--any` | Match ANY search term instead of ALL (OR) | |
| `-f`, `--full-text` | Include transcript content in search (shows snippets) | |
| `--project` | Filter by project (directory) name | |
| `--branch` | Filter by git branch (substring) | |
| `--since` / `--until` | Filter by last activity: `7d`/`24h`/`2w` or `YYYY-MM-DD` | |
| `--date` | Filter by date prefix | |
| **Display modifiers** |
| `--tokens` | Show token usage and cost inline | ✓ |
| `--size` | Show transcript file sizes inline | ✓ |
| `--context` | Show peak context window inline (model-aware ⚠) | ✓ |
| `--detail` | Expanded per-session breakdown | |
| `-v`, `--verbose` | Show more messages per session | ✓ |
| **Listing** |
| `-n`, `--limit` | Limit number of results | |
| `--reverse` | Show oldest first | |
| `--sort` | Sort by: `date` (start), `recent` (last activity), `tokens`, `cost`, `size`, `messages` | |
| **Actions** |
| `--show ID` | Print a session's conversation | |
| `--grep TERMS` | With `--show`, only matching turns (highlighted) | |
| `--last N` | With `--show`, only the final N turns | |
| `--no-summary` | With `--show`, skip compaction-summary turns | |
| `--text-only` | With `--show`, only turns with prose (drop tool-only) | |
| `--resume ID` | Print the command to resume a session (with `cd`) | |
| `--exec` | With `--resume`, run the command instead of printing | |
| `--set-name ID NAME` | Assign a name to a session | |
| `--unname ID` | Remove a session's name | |
| `--remove ID` | Remove a specific session transcript | |
| `--clean` | Bulk cleanup old transcripts | |
| `--prune-empty` | Remove throwaway sessions (≤1 prompt) | |
| `--older-than` | Days threshold for --clean (default: 90) | |
| `--dry-run` | Preview without deleting | |
| `--stats` | Summary statistics (incl. cache efficiency) | |
| **Export** |
| `--export` | Export as `json` or `csv` | |

## `cc` — Session wrapper

The `cc` command wraps `claude` with two quality-of-life prompts:

1. **On start** — asks for a session name (colorized, skippable with Enter)
2. **On exit** — asks whether to keep, discard, or bulk-clean old transcripts

Three equivalent versions are included — symlink/alias whichever matches your shell to `cc`:

| Shell | File |
|-------|------|
| zsh | `cc` |
| bash | `cc.bash` |
| Windows PowerShell | `cc.ps1` |

All three honor the same `CC_SKIP_NAME` / `CC_SKIP_EXIT` / `CC_AUTO_CLEAN_DAYS` settings.

```
$ cc
Session name (enter to skip): TEL GPU capacity planning
→ TEL GPU capacity planning

[... normal Claude Code session ...]

Keep this session transcript? [Y/n/clean]: y
Session kept.
```

### Options at exit

| Input | Action |
|-------|--------|
| `y` or Enter | Keep the transcript (default) |
| `n` | Delete the transcript for the session that just ended |
| `clean` | Run `claude-recall --clean` to bulk-remove old transcripts |

### Configuration

Set these in your `.zshrc` to change behavior:

```bash
export CC_SKIP_NAME=1          # Never prompt for session name
export CC_SKIP_EXIT=1          # Never prompt on exit
export CC_AUTO_CLEAN_DAYS=60   # Days threshold for 'clean' option (default: 90)
```

The wrapper is transparent — all arguments pass through to `claude`:

```bash
cc --model sonnet           # session name prompt, then launches with sonnet
cc -n "already named"       # skips name prompt (already provided)
cc -p "one-shot question"   # skips both prompts (print mode)
```

---

## How Claude Code stores sessions

```
~/.claude/
├── history.jsonl              # Index of all prompts (lightweight, never deleted)
├── .claude-recall-cache.json  # claude-recall's own metadata cache (auto-managed)
├── .claude-recall-names.json  # your --set-name labels (auto-managed)
├── sessions/                  # Active session PIDs
│   └── 45394.json
└── projects/                  # Transcripts organized by working directory
    ├── -Users-you/            # Sessions started from ~/
    │   ├── abc123.jsonl       # Full conversation transcript
    │   └── abc123/            # Subagent transcripts, tool results
    ├── -Users-you-myrepo/     # Sessions started from ~/myrepo
    └── ...
```

- **Transcript JSONL** — full conversation including assistant responses, tool calls, usage data, the working directory, and git branch. **This is what `claude-recall` indexes.** These are the large files.
- **history.jsonl** — one line per prompt you sent. `claude-recall` reads it only to keep showing sessions whose transcript has been deleted (marked `-`).
- Session IDs are UUIDs. The project directory name is the working directory path with `/` replaced by `-`.

### The cache

`claude-recall` builds its index by scanning every transcript, then caches the parsed metadata in `~/.claude/.claude-recall-cache.json`. On later runs it re-parses only the transcripts whose `mtime`/`size` changed — so a repeat run is near-instant even with hundreds of sessions. The cache is fully disposable: delete it any time and it rebuilds on the next run.

## Configuration

Set `CLAUDE_DIR` environment variable if your Claude config lives somewhere non-standard:

```bash
export CLAUDE_DIR=/custom/path/.claude
```

Cost estimates use default Opus pricing. Edit the `PRICING` dict in the script to adjust rates.

The context-window warning (⚠) fires at 90% of the model's window by default. Override the threshold with `CLAUDE_RECALL_CTX_WARN` (e.g. `export CLAUDE_RECALL_CTX_WARN=0.8`).

## Tips

- **Use `cc` instead of `claude`** to get automatic name prompts, or name manually with `claude -n "my session"` — named sessions are easier to find with both `/resume` and `claude-recall`.
- **Jump back into any session** with `claude-recall --resume <prefix>` — it hands you the `cd` + `claude --resume` command, so you don't have to remember which directory the session belonged to.
- **Transcripts get pruned** over time. If a session shows `-` (history only), the full transcript was cleaned up. The message index in history.jsonl persists.
- **Full-text search** (`-f`) is slower because it reads every transcript file on disk. Use keyword search first, add `-f` if you need to search assistant responses.

## License

MIT
