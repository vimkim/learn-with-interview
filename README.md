# learn-with-interview

A Claude Code plugin that turns any reading material into a Socratic drill session. You hand Claude a paper, article, or doc — Claude extracts the key concepts, then interviews you one question at a time until you demonstrate deep understanding across four rubric dimensions.

Mastery is measured, not vibes-based: every answer is scored 0.0–1.0 on the probed dimensions, an exponential moving average tracks your running competence per dimension, and the loop only terminates when all four dimensions are at the gate (≥ 0.80 EMA) for two consecutive rounds — or you hit the 20-round cap, or type `stop`.

## Why this exists

"I read the paper" and "I understand the paper" are different claims. This plugin stress-tests the second one. It forces you to:

- **Recall** the facts the author actually stated
- **Reason** about *why* the mechanism works, not just *that* it works
- **Apply** the concept to a scenario the author never mentioned
- **Synthesize** — connect it to other ideas, critique it, name its limits

If any of those four dimensions stays weak, the loop keeps targeting it.

## What a session looks like

```
$ claude --plugin-dir /path/to/learn-with-interview
> /learn-with-interview:start ./papers/raft-consensus.pdf

I've read the material. Here are the 8 key concepts I'll probe you on:
1. Leader election — ...
2. Log replication — ...
...

Round 1 | Targeting: recall (EMA 0.00) | Concept: Leader election
Under what condition does a Raft follower start an election?

  [a] When it receives AppendEntries from a newer term
  [b] When its election timeout elapses without hearing from the leader
  [c] When a majority of peers become unreachable
  [Other — type your own]

> b

Correct. The paper (§5.2) specifies that followers become candidates
"if a follower receives no communication over a period of time called
the election timeout". You nailed the trigger but didn't mention the
term-increment step — a candidate increments currentTerm before
requesting votes.

| Dim       | This | EMA  | Gate |
|-----------|------|------|------|
| Recall    | 0.80 | 0.80 | ✓    |
| Reasoning | —    | 0.00 | ✗    |
| Applic'n  | —    | 0.00 | ✗    |
| Synthesis | —    | 0.00 | ✗    |

Gate streak: 0/2 | Next weakest: reasoning (EMA 0.00)
```

The loop keeps going, targeting whichever dimension has the lowest EMA, until you hit the gate or quit.

## Install

### Local development (no marketplace needed)

```bash
claude --plugin-dir /path/to/learn-with-interview
```

The `--plugin-dir` flag loads the plugin for this session only. Great for iterating.

### Via a plugin marketplace

Publish the plugin through a Claude Code plugin marketplace, then:

```
/plugin install learn-with-interview@<your-marketplace>
```

See [Claude Code plugins docs](https://code.claude.com/docs/en/plugins) for marketplace authoring.

### Requirements

- Claude Code **2.1+** (plugins support)
- **Python 3.6+** in `PATH` (stdlib only — `sqlite3`, `argparse`, `json`, `hashlib`)

No pip install, no extra binaries. The bundled `bin/lwi` script is added to your shell `PATH` automatically while the plugin is active.

## Usage

```
/learn-with-interview:start ./path/to/material.md
/learn-with-interview:start https://example.com/article
/learn-with-interview:start ./paper.pdf
```

Arguments are auto-detected:
- `http://` / `https://` → fetched via `WebFetch`
- anything else → read via `Read` (PDFs supported via the `pages` param)
- empty → the skill asks you for a source

At any point during the interview, type `stop` / `quit` / `enough` to terminate the loop early and still get a report with your current scores.

### Resuming

Run `/learn-with-interview:start` with the **same source** and it auto-detects the prior session (matched by SHA-256 of the source + its first 64 KB of content) and offers to resume. To force a fresh session instead, have Claude run `lwi init --fresh "<source>"` manually, or delete `.learn-with-interview.db`.

## How it works

The plugin cleanly splits work between the **LLM** (irreducibly judgment-based) and a **deterministic CLI** (everything else). This keeps sessions cheap in output tokens and auditable on disk.

```
┌─────────────────────────────┐     ┌──────────────────────────────┐
│ Claude (the LLM)            │     │ bin/lwi (Python + SQLite)    │
├─────────────────────────────┤     ├──────────────────────────────┤
│ • Read the source           │     │ • Session / round persistence│
│ • Extract key concepts      │     │ • EMA math (α = 0.4)         │
│ • Generate ONE question     │ ──► │ • Weakest-dim tracking       │
│   per round (targets the    │     │ • Gate check + streak count  │
│   weakest dimension)        │     │ • Final report generation    │
│ • Critique the answer, cite │ ◄── │ • Resume matching            │
│   the source                │     │                              │
│ • Score each probed dim     │     │                              │
└─────────────────────────────┘     └──────────────────────────────┘
```

### The rubric

Every question targets the dimension whose running EMA is currently lowest. Every answer is scored 0.0–1.0 on the dimensions that question actually probed.

| Dimension   | What it measures                                              |
|-------------|---------------------------------------------------------------|
| Recall      | Did you state the facts from the material correctly?          |
| Reasoning   | Did you explain the WHY / mechanism, not just restate?        |
| Application | Can you apply the concept to a scenario NOT in the material?  |
| Synthesis   | Can you connect, critique, or spot limitations?               |

Score anchors: `1.0` exact, `0.7` mostly correct with a minor gap, `0.4` partially correct with a major gap, `0.0` wrong or empty. Dimensions the question did not probe are skipped (not penalized).

### The mastery gate

Running mastery per dimension is tracked as an **exponential moving average** with `α = 0.4`:

```
ema_new = (1 - α) * ema_prev + α * this_round_score
```

(First probe of a dimension seeds the EMA directly with the score, no averaging against a 0.)

**Termination conditions** (whichever fires first):
1. All four EMAs ≥ **0.80** for **2 consecutive rounds** → `MASTERY_GATE_MET`
2. Round count reaches **20** → `MAX_ROUNDS`
3. User types stop/quit/enough → `USER_STOPPED`

All three produce a final markdown report.

### Files written in your working directory

| File                                            | Owner | Purpose                             |
|-------------------------------------------------|-------|-------------------------------------|
| `.learn-with-interview.db`                      | `lwi` | SQLite: session + concepts + rounds |
| `.learn-with-interview-report-<slug>.md`        | `lwi` | Final transcript + mastery report   |

Nothing else is touched. To reset completely, delete the `.db` file.

## CLI reference

Claude calls `lwi` on your behalf during sessions, but you can drive it manually too.

```
lwi init <source> [--fresh]            # Create or resume a session
lwi set-concepts --session N           # Store extracted concepts (JSON on stdin)
lwi next-target  --session N           # Get current weakest dim + candidate concepts
lwi score        --session N           # Record one round (JSON payload on stdin)
lwi status       --session N           # Dump current state as JSON
lwi stop         --session N           # Mark session USER_STOPPED
lwi report       --session N           # Write final report markdown file
```

All commands emit JSON to stdout. Mutating commands read a JSON payload from stdin. Example:

```bash
echo '{"concept":1,"dim":"recall","question":"What is X?","answer":"...",
       "critique":"...","recall":0.8,"reasoning":-1,"application":-1,"synthesis":-1}' \
  | lwi score --session 1
```

Scores of `-1` mean "this dimension was not probed this round" — the EMA for that dimension is preserved.

### Configuration constants

Edit the top of `bin/lwi` to change the gate behavior:

```python
ALPHA = 0.4           # EMA smoothing factor
GATE = 0.80           # Required EMA per dimension
STREAK_NEEDED = 2     # Consecutive rounds at gate to terminate
MAX_ROUNDS = 20       # Hard cap
```

## Design notes

### Why externalize state to a CLI?

A naive implementation would have Claude write a growing JSON state file every round, recompute EMAs in its head, re-render rubric tables in chat, and compose a multi-kilobyte final report — all as output tokens. For a 10-round session, that's roughly **5000 output tokens** of pure bookkeeping.

Delegating persistence, arithmetic, and report assembly to `bin/lwi` cuts that to about **1500 output tokens** (~70% reduction) because:
- Claude never writes the state JSON — it sends an 8-line `score` payload and the CLI updates SQLite
- Claude never re-renders the rubric table — the CLI emits a `display` string Claude passes through
- Claude never composes the final report — `lwi report` scans the DB and writes the file in one pass
- The `SKILL.md` prompt itself is ~45% smaller because the state-management protocol collapses to a handful of `lwi` subcommand calls

The LLM does what only an LLM can do (semantic judgment) and the computer does what a computer should do (arithmetic and storage).

### Why SQLite?

- Atomic round-commits (no corruption if you Ctrl-C mid-write)
- Cheap resume — one indexed query by source hash
- Self-contained, no new dependencies
- Final report generation is a single DB scan

## Project structure

```
learn-with-interview/
├── .claude-plugin/
│   └── plugin.json         # Manifest (name, version, author)
├── bin/
│   └── lwi                 # Python 3 CLI; on $PATH when plugin active
├── skills/
│   └── start/
│       └── SKILL.md        # Socratic interview protocol (LLM side)
└── README.md
```

## License

MIT
