# INCMPRSBL - Build Notes

## Phase 1: Initial Build (2026-03-23)

Built INCMPRSBL as a Claude Code skill that compresses articles to their incompressible form. The skill maps 17 content types (process, argument-sequential, framework, concept, etc.) to optimal visual formats (checklist, table, flowchart, concept-map, etc.).

**Key design decision:** Format is determined by information shape, not by author preference. A process gets a checklist. A comparison gets a table. A concept with relationships gets a concept map. The compressor classifies, then renders.

**Technology:** Pure HTML output. No build system. Templates in `templates/output.html` and `templates/index.html`. Mermaid.js for diagrams. GitHub Pages for hosting. Stats tracked in `stats.json`.

## Phase 2: Faithfulness Crisis (2026-03-25)

### What happened

Ran independent evaluation on 8 compressed articles. Average accuracy was 83.0. Three failure modes surfaced:

1. **External knowledge injection** (Yamanaka article, scored 67/100): The compression added timeline entries (2006, 2012 Nobel, 2020 Sinclair, 2024 Macip), study citations, and specific statistics (109% lifespan, AAV9, doxycycline) that were not in the original article. They were factually correct from external knowledge, but the article never mentioned them. This is hallucination in the context of compression.

2. **Claim reversal** (AI Revolution, scored 80.1/100): The compression said ASI "could follow AGI within decades." The original said "within hours" (specifically 90 minutes). This was the article's most striking claim, completely inverted. The compressor remembered the topic but not the specifics.

3. **Gap filling** (multiple articles): Adding context the reader "needs" that the author didn't provide. Defining terms the author left undefined, adding timelines the author omitted.

### The fix

Added a cardinal rule to the skill:

> Every single claim in the output must point to a specific sentence in the original article. No exceptions. No inferring. No assuming. No external knowledge.

Added mandatory autoresearch pass with claim-by-claim tracing: for every claim in the compression, find the specific sentence in the original that supports it. Claims without a traceable source get removed.

### Self-evaluation bias

The first round of "improved" scores came from the same agent that did the compression. Self-evaluation was 2-3 points more generous than independent evaluation. The compressor has already committed to its framing and is inherently generous about its own work.

**Fix:** Evaluation must be a separate agent that only sees the compressed output and the original article, with no memory of the compression process.

### Results after fix

| Article | Before | After (independent eval) |
|---------|--------|--------------------------|
| Yamanaka | 67 | 89.5 (accuracy 94) |
| AI Revolution | 80.1 | 89.9 (accuracy 95) |
| World Order | 88.2 | 91.8 (accuracy 100) |
| Average (8 articles) | 83.0 | 89.8 (accuracy 96.8) |

Zero hallucinations across all 8 articles. Zero claim reversals.

## Phase 3: Skill-Level Autoresearch (2026-03-25)

### The insight

Autoresearch works at two levels:

**Article-level:** Change one claim in the compression, re-evaluate, keep or revert. This fixes individual articles but doesn't improve future ones.

**Skill-level:** Identify failure patterns across multiple articles, change one rule in the skill, recompress an article that exhibited the pattern, independent evaluation, compare to baseline. This improves the process for all future articles.

Same three primitives, different editable asset:

| Primitive | Article-level | Skill-level |
|-----------|--------------|-------------|
| Editable asset | One HTML file | SKILL.md |
| Scalar metric | One article's score | Avg score across batch |
| Cycle | Change one claim | Change one rule |

### First skill-level iteration

**Pattern identified:** "Structured formats create pressure to fill gaps with inference." Table cells need content, flowchart paths need destinations, concept maps need connections. When the source doesn't provide enough detail, the compressor fills the gap with plausible inference.

Evidence across articles:
- When to Quit: table cells elaborated "professional development" into "new skills, increasing responsibility"
- Yamanaka: flowchart assigned cancer risk specifically to full reprogramming (source left it ambiguous)
- Autoresearch: table label inferred "MLX" from repo name, not article text
- AI Revolution: added "not because of strength" contrast framing the source didn't state

**Rule added:** "Structural gaps rule" - when a format requires more specificity than the source provides, use the source's exact language even if vague. An accurate vague cell is better than a specific inferred one. If the format needs more than the source provides, switch to a less structured format rather than fabricate detail.

**Iteration cycle:** Recompressing "When to Quit" (lowest scorer at 84.4) with the updated skill, then independent evaluation to measure the delta.

### When to run skill-level autoresearch

After evaluating a batch (5+ articles), not after every article. Individual articles have too much noise. Batch evaluation surfaces patterns:
- Single-article issues = execution errors (fix the article)
- Multi-article issues = process errors (fix the skill)

## Phase 4: Image Extraction Gate (2026-03-25)

### What happened

The INCMPRSBL article contained a format mapping table as an embedded image. The accessibility snapshot showed `[Image]` but the compressor skipped past it without extracting the content. The compression was missing the entire 17-row format mapping table, which is the core reference of how the tool works.

The skill already had a "Data-bearing images" section with extraction instructions. The instructions were correct and thorough. The compressor just didn't follow them.

### The insight

There's no such thing as an execution error that isn't a process error. If the process was good enough, you'd follow it every time. The image extraction instructions were written as guidance buried in the middle of Step 1, easy to skip because nothing enforced them.

### The fix

Restructured image extraction from a sub-section of Step 1 into a mandatory gate (Step 1B) between fetching and compressing. The gate:
1. Forces explicit listing of every image found
2. Forces classification of each as decorative or data-bearing
3. Forces extraction of all data-bearing images before proceeding
4. Requires a verbal checkpoint: "Image gate: N images found, M data-bearing, all extracted"
5. Defines a failure condition: you cannot proceed to Step 2 with unextracted data-bearing images

The key structural change: moving from "check for images" (optional-sounding) to "you are blocked until images are processed" (mandatory gate). Same content, different control flow.
