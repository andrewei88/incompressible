# AI Article Compression Skill

Compress AI articles to their incompressible form: the point where removing anything else would lose meaning.

## Classification

Identify distinct sections of the article. Each section has one dominant information type:

| Type | What it looks like |
|------|-------------------|
| argument-sequential | Reasoning chain where each point depends on the previous |
| argument-parallel | Independent claims or observations that stand alone |
| framework | Named components with parallel attributes |
| comparison | Evaluating options against the same criteria |
| concept | Ideas defined by relationships to other ideas |
| process | Step-by-step instructions or workflows |
| sequence | Ordered events where order matters |
| catalog | A list or collection of items meant as a reference |

**Disambiguation:**
- If each point depends on the previous → argument-sequential
- If points stand alone → argument-parallel
- If components have parallel attributes but no relationships → framework
- If components interact or cause each other → concept

## Format mapping

| Type | Format |
|------|--------|
| argument-sequential | key-points |
| argument-parallel | key-points |
| framework | table |
| comparison | table |
| concept | concept-map |
| process | checklist |
| sequence | numbered-steps |
| catalog | reference-table |

## Compression rules

**Keep:**
- Core claims and arguments
- Specific numbers, parameters, benchmarks, dates
- Named tools, models, frameworks, versions
- Actionable steps
- Key distinctions
- Evidence supporting non-obvious claims
- Hedging and epistemic markers (seems, appears, I think, likely, might, suggests) — these signal the author's uncertainty, not filler. If the author hedges a claim, the compression must hedge it too.
- Numerical thresholds, limits, and ceilings (e.g., "tops out after ~5 models", "only works above 50B parameters") — these specific bounds distinguish expert knowledge from generic advice
- Code examples that demonstrate a key concept, especially bug patterns and fixes. Reproduce the essential lines, not the full snippet. If the code IS the point (e.g., showing a bug mechanism), it must survive compression.
- Enumerated categories and illustrative examples with specific details: When an article names specific categories, phases, or types that organize a framework (e.g., "four phases: X, Y, Z, W"), list them explicitly — don't summarize as "by [grouping]." When an article uses a concrete example with specific numbers or quotes to demonstrate a capability, preserve the example's key specifics — they serve as evidence, not decoration.

**Preserve framing claims:** If the article opens with a specific motivating problem or question (e.g., "students asked why X", "we discovered Y was broken"), keep it — it's a claim, not filler. Similarly, if the conclusion makes a specific, testable assertion (e.g., "95% of materials do X wrong"), preserve it. Only discard introductions and conclusions that are generic summaries with no new claims. The motivating context (who complained, what they asked, what event triggered the article) is often the most memorable part of the piece. If it names a specific group, institution, or event, it must survive compression.

**Discard:**
- Anecdotes used purely for engagement (keep the point, cut the story)
- Analogies that restate a point already made plainly
- Repetition
- Generic filler transitions and introductions that make no new claims
- Social proof and credibility markers

**Disambiguation:** When an article describes an automated or autonomous system, its tooling choices (e.g., git for versioning, Docker for isolation, cron for scheduling) are architectural decisions, not filler. Keep them.

**Post-compression check for systems:** If the article describes a system with an autonomous or automated loop, verify your compression preserves: (1) what the loop does, (2) how it manages state between iterations (e.g., git commits, checkpointing, logging), and (3) how it handles failure (e.g., revert, retry, alert). These mechanisms are architectural, not implementation details.

**Style:**
- Short sentences. If a sentence has a comma, consider splitting it.
- Simple words. "Use" not "utilize."
- One idea per paragraph.

## Compression intensity

- Padded articles (heavy engagement hooks, humor): 5-10%
- Average-density articles: 8-15%
- Dense/technical articles: 15-25%
- Already-compressed sources (READMEs, documentation, API references): 25-40%
- Never below 5%
