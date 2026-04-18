# learn-with-interview

A Claude Code plugin that helps you learn a topic deeply by interviewing you Socratically on provided reading material.

Give it a file or URL. It reads the material, extracts the key concepts, then asks you one question at a time across four rubric dimensions — **recall**, **reasoning**, **application**, **synthesis** — and critiques each answer with citations from the source. It loops until you reach a mastery gate (EMA ≥ 0.80 on all four dimensions for 2 consecutive rounds) or 20 rounds, whichever comes first.

## Install

### Local development

```bash
claude --plugin-dir /path/to/learn-with-interview
```

### Via a marketplace

Publish through a Claude Code plugin marketplace, then:

```
/plugin install learn-with-interview@<your-marketplace>
```

## Usage

```
/learn-with-interview:start ./paper.md
/learn-with-interview:start https://example.com/article
```

Auto-detects file paths vs URLs. Uses `Read` for local files, `WebFetch` for URLs.

## How it works

1. **Ingest** the material and extract 5–12 key concepts with citations.
2. **Loop:** one question per round, targeting your weakest dimension. Each answer scored 0.0–1.0 per probed dimension; EMA (α=0.4) tracks running mastery.
3. **Gate:** terminates when all four dimension EMAs ≥ 0.80 for 2 consecutive rounds.
4. **Report:** writes a transcript + mastery breakdown + "still-weak concepts" list to `.learn-with-interview-report-<slug>.md`.

Session state is persisted to `.learn-with-interview-state.json` so you can resume.

Type `stop` at any time to end early and get a report with current scores.

## Rubric

| Dimension | What it measures |
|-----------|------------------|
| Recall | Did you state the facts from the material correctly? |
| Reasoning | Did you explain the WHY / mechanism, not just restate? |
| Application | Can you apply the concept to a new scenario not in the material? |
| Synthesis | Can you connect, critique, or spot limitations? |

## Structure

```
learn-with-interview/
├── .claude-plugin/
│   └── plugin.json
├── skills/
│   └── start/
│       └── SKILL.md
└── README.md
```

## License

MIT
