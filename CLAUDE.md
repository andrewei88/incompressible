# INCMPRSBL Project

## Faithfulness is the primary metric
Every claim in a compressed article must trace to a specific sentence in the original. No external knowledge, no inferring, no gap-filling. A factually correct claim not in the original is a hallucination. This overrides compression ratio, format choice, and style.

## Independent evaluation
When evaluating compressed articles, the evaluator must be a separate agent from the compressor. Self-evaluation is inherently generous. The evaluator re-reads the original source cold and does claim-by-claim tracing. Three known failure modes: (1) external knowledge injection, (2) claim reversal, (3) gap filling.

## Article pipeline
- Skill: `/inc` (defined in `~/.claude/skills/inc/SKILL.md`)
- Stats: `stats.json` tracks all articles, word counts, time saved
- Index: `index.html` is regenerated from `templates/index.html` after each compression
- Articles: `YYYY-MM-DD-slug.html` generated from `templates/output.html`
- Settings: `settings.json` maps 17 content types to visual formats

## Index page rules
- Only list articles that are tracked in git (not gitignored)
- The index shows a subset of stats.json; don't assume all entries belong in the index
