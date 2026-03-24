# INCMPRSBL

Compresses articles to the point where removing anything else would lose meaning.

**Live site:** [andrewei88.github.io/incompressible](https://andrewei88.github.io/incompressible/)

## What it does

You give it a URL (or paste text), and it outputs a self-contained HTML page with the article compressed and structured in the format that best fits each section's information type:

| Information type | Rendered as |
|---|---|
| Linear process | Checklist or numbered steps |
| Parallel arguments | Bullet points |
| Framework / comparison | Table |
| Branching decisions | Flowchart (Mermaid.js) |
| Interconnected concepts | Concept map (Mermaid.js) |
| Sequential reasoning | Chain notation (A → B → C) |
| Persuasive prose | Prose (keeps the logical thread intact) |

Typography adapts too. Scannable formats (tables, checklists) use 14px. Prose uses 17px with wider line-height. The size shift signals how to read each section.

## Requirements

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (requires a Pro or Max subscription, or API key)
- [Playwright MCP server](https://github.com/anthropics/claude-code/blob/main/docs/mcp.md) (optional, only needed for X/Twitter content behind login walls)

## Setup

1. Clone this repo:
   ```
   git clone https://github.com/andrewei88/incompressible.git ~/Projects/incompressible
   ```

2. Copy the skill file to your Claude Code skills directory:
   ```
   mkdir -p ~/.claude/skills/inc
   cp ~/Projects/incompressible/SKILL.md ~/.claude/skills/inc/SKILL.md
   ```

3. For X/Twitter support, set up a persistent Playwright profile:
   ```
   mkdir -p ~/.playwright-profile
   ```
   Then log into X once in the Playwright browser window. Cookies persist for future use.

## Usage

In Claude Code, type:

```
/inc https://example.com/article
```

Or paste text directly:

```
/inc [paste article text here]
```

The tool fetches the article, classifies each section by information type, compresses it, and outputs a self-contained HTML file. The file opens in your browser automatically.

### X/Twitter content

Single tweets, threads, and X Articles all work. The tool tries the fastest method first (fxtwitter API, no auth needed for public tweets) and falls back to Playwright for login-gated content.

If a URL returns "page not found" (common when usernames change), the tool tries resolving by status ID alone before asking you to verify the URL.

## Configuration

Edit `~/Projects/incompressible/settings.json` to customize format mappings:

```json
{
  "formatMapping": {
    "process": "checklist",
    "argument-sequential": "reasoning-chain",
    "argument-parallel": "key-points",
    "framework": "table",
    "comparison": "table",
    "concept": "concept-map",
    "decision-tree": "flowchart",
    "action-items": "checklist",
    "sequence": "numbered-steps",
    "catalog": "reference-table"
  },
  "globalPreference": "auto"
}
```

`globalPreference` options:
- `auto` (default): picks the best format for each section
- `visual`: biases toward concept maps and flowcharts
- `text`: biases toward prose and lists

## How compression works

Two questions guide every sentence:

1. **If I remove this, does the reader do or believe something different?** Keep it.
2. **If I remove this, does the reader just feel less entertained or persuaded?** Cut it.

After compression, three checks catch what the first pass misses:
- **Buried claims:** strong claims hidden inside paragraphs about other topics
- **Beneficiary/stakes:** if the original names a person and a specific reward, both must appear
- **Most-quotable line:** lines a reader would quote when sharing the article are kept verbatim

## Output

Each compressed article is a self-contained HTML file saved to `~/Projects/incompressible/`. No server, no database, no build step. Mermaid.js loads via CDN only on pages that use flowcharts or concept maps.

The index page at `index.html` lists all compressed articles with search and tracks total reading time saved.
