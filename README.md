# INCMPRSBL

Compresses articles to the point where removing anything else would lose meaning.

**Live site:** [andrewei88.github.io/incompressible](https://andrewei88.github.io/incompressible/)

## What it does

You give it a URL (or paste text), and it outputs a self-contained HTML page with the article compressed and structured in the format that best fits each section's information type:

| Information shape | Format | Why |
|---|---|---|
| Linear process | Checklist / numbered steps | Order matters, track progress |
| Parallel arguments | Bullet points | Independent claims, order doesn't matter |
| Sequential reasoning | Chain (A → B → C) | Each point builds on the last |
| Framework / comparison | Table | Shared attributes, scan and compare |
| Catalog / reference list | Reference table | The value IS the list |
| Before / after | Side-by-side table | Two-state comparison |
| Dated events | Timeline | Years are load-bearing |
| Branching decisions | Flowchart | If X, do Y |
| Cycles | Flowchart with loop-back | The loop IS the insight |
| Interconnected concepts | Concept map | Relationships are the point |
| Hierarchical concepts | Mindmap | Categories and subcategories |
| Interactions | Sequence diagram | Back-and-forth flows |
| 2x2 frameworks | Quadrant chart | Effort/impact, risk/reward |
| Proportions | Pie chart | Budget splits, market share |
| Numeric comparisons | Bar chart | Benchmarks, rankings |
| User journeys | Journey map | Emotional arc matters |
| Persuasive prose | Prose | Logical thread breaks if unbundled |

Timelines render as custom HTML (vertical line with year markers). Mermaid.js is only loaded for formats that need graph layout (concept maps, flowcharts, mindmaps, sequence diagrams, quadrant/pie/bar charts, journey maps).

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

The tool fetches the article, classifies each section by information type, compresses it, runs a post-compression accuracy check with an autoresearch pass, and outputs a self-contained HTML file that opens in your browser.

### X/Twitter content

Single tweets, threads, and X Articles all work. The tool tries the fastest method first (fxtwitter API, no auth needed for public tweets) and falls back to Playwright for login-gated content.

If a URL returns "page not found" (common when usernames change), the tool tries resolving by status ID alone before asking you to verify the URL.

## Configuration

Edit `~/Projects/incompressible/settings.json` to customize format mappings:

```json
{
  "formatMapping": {
    "process": "checklist",
    "argument-sequential": "key-points",
    "argument-parallel": "key-points",
    "framework": "table",
    "comparison": "table",
    "concept-causal": "concept-map",
    "concept-hierarchical": "mindmap",
    "decision-tree": "flowchart",
    "action-items": "checklist",
    "sequence": "numbered-steps",
    "catalog": "reference-table",
    "chronology": "timeline",
    "interaction": "sequence-diagram",
    "quadrant": "quadrant-chart",
    "data-breakdown": "pie-chart",
    "data-comparison": "bar-chart",
    "transformation": "before-after",
    "experience": "user-journey"
  },
  "globalPreference": "auto"
}
```

`globalPreference` options:
- `auto` (default): picks the best format for each section
- `visual`: biases toward concept maps, mind maps, and flowcharts
- `text`: biases toward prose and lists

## How compression works

The primary metric is accuracy. Every claim in the output must trace back to the original. Completeness and brevity matter, but never at the cost of faithfulness.

Two questions guide every sentence:

1. **If I remove this, does the reader do or believe something different?** Keep it.
2. **If I remove this, does the reader just feel less entertained or persuaded?** Cut it.

After compression, four checks catch what the first pass misses:
- **Buried claims:** strong claims hidden inside paragraphs about other topics, author-emphasized text, concrete data in narrative paragraphs
- **Beneficiary/stakes:** if the original names a person and a specific reward, both must appear
- **Most-quotable line:** lines a reader would quote when sharing the article are kept verbatim
- **Faithfulness:** no invented claims, no shifted framing, no flattened probabilities (">50% chance by 2040" stays hedged, not "prediction: 2040")

Articles with embedded images (tables, charts, diagrams) go through a mandatory image extraction gate before compression. Every image is listed, classified as decorative or data-bearing, and data-bearing images are screenshot-extracted using Claude's multimodal capability. Compression cannot proceed until all data-bearing images are processed. This prevents silent data loss from text-only extraction.

Every compression then gets an autoresearch pass: single-variable iteration to fix any issues found. Change one thing, verify it improves accuracy without degrading compression, keep or discard.

Evaluation uses a separate agent from the compressor. Self-evaluation is inherently generous (the agent that wrote the compression has already committed to its framing). The independent evaluator reads only the compressed output and the original article, with no memory of the compression process. It does claim-by-claim tracing: for each claim in the output, find the specific sentence in the original that supports it. Claims without a traceable source are hallucinations, even if factually correct.

## How the rules were developed

The compression rules and format mappings were optimized using single-variable iteration (inspired by Karpathy's autoresearch pattern): change one thing in the skill prompt, compress an article, score the output, keep or revert. No batching multiple changes.

Tested against 19 articles across 5 rounds:
- **Rounds 1-2:** Training on Paul Graham essays to tune compression and format rules
- **Round 3:** Adversarial testing with edge cases (catalogs, already-compressed content, satirical writing)
- **Round 4:** Single-variable optimization, one change per cycle
- **Round 5:** Validation on 7 articles never seen during tuning (Quanta Magazine, technical tutorials, X threads, opinion pieces)

Results: training average 93.5%, validation average 91.1%. The 2.4-point gap confirmed the rules weren't overfitting to Paul Graham's writing style. Scoring rubric: Accuracy 40%, Format choice 25%, Compression ratio 15%, Style 20%.

## Output

Each compressed article is a self-contained HTML file saved to `~/Projects/incompressible/`. No server, no database, no build step.

The index page at `index.html` lists all compressed articles with search and tracks total reading time saved.
