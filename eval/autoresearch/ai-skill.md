# AI Article Compression Skill

Compress AI articles to their incompressible form: the point where removing anything else would lose meaning.

## Classification

Identify distinct sections of the article. Each section has one dominant information type. Choose the most specific type that fits — specific types produce faster-to-scan visual formats.

| Type | What it looks like | Renders as |
|------|-------------------|------------|
| argument-sequential | Multi-sentence points where each depends on the previous | bullet list |
| argument-parallel | Independent claims with no shared structure between items | bullet list |
| reasoning-chain | Short logical chain: A therefore B therefore C (≤5 items, each ≤1 sentence) | visual chain with arrows |
| transformation | Contrasting two states: before/after, old/new, small-scale/large-scale | two-column layout |
| framework | Named components with parallel attributes | table |
| comparison | Evaluating options against the same criteria or benchmarks | table |
| data-comparison | Quantitative comparison: benchmark scores, metrics, performance numbers | bar chart |
| data-breakdown | Proportional breakdown of a whole (X% is A, Y% is B) | pie chart |
| concept-causal | Ideas connected by cause-effect or influence relationships | concept map (diagram) |
| concept-hierarchical | Ideas in parent-child or category-subcategory structure | mindmap (diagram) |
| decision-tree | Branching logic: if X then Y, if Z then W | flowchart (diagram) |
| interaction | Multiple entities exchanging messages or data (API calls, agent loops) | sequence diagram |
| process | Step-by-step instructions or linear workflows | checklist |
| action-items | Concrete tasks or recommendations to act on | checklist |
| sequence | Ordered events where order matters | numbered steps |
| chronology | Events with specific dates or time periods | timeline |
| quadrant | Items categorized along two independent axes (e.g., cost vs quality) | quadrant chart |
| catalog | A list or collection of items meant as a reference | reference table |
| experience | A user or entity's journey through stages with pain points | journey diagram |
| code-example | A section whose primary content is a code snippet demonstrating a key concept, bug pattern, or technique | code block (monospace) |

**Disambiguation (pick the most specific type):**
- Points depend on each other AND are short single sentences → reasoning-chain
- Points depend on each other AND are multi-sentence with evidence → argument-sequential
- Points stand alone AND share a two-dimensional structure (finding/detail, claim/evidence) → framework (renders as table)
- Points stand alone AND contrast two states → transformation
- Points stand alone with no shared structure → argument-parallel
- Components have parallel attributes but no relationships → framework
- Components interact or cause each other → concept-causal
- Components nest in hierarchy → concept-hierarchical
- Quantitative scores across models/methods → data-comparison
- Proportions of a whole → data-breakdown
- "Use X when A, use Y when B" decision logic → decision-tree
- Section centers on a code snippet (the code IS the point, not just supporting evidence) → code-example. Use when the article shows a bug pattern, a key API call, a config change, or a technique where seeing the code is faster than describing it in prose. If code is supplementary to a prose explanation, keep the code inline within the prose section's format instead.
- A process that repeats in a cycle (modify → evaluate → keep/discard → repeat) → decision-tree (flowchart), NOT reasoning-chain, sequence, or argument-parallel. The cycling structure IS the insight. Reasoning-chain shows A→B→C→D linearly but hides the loop. A flowchart with an arrow from the last node back to the first communicates the cycle visually. Look for: "repeats," "loop continues," "keeps or discards and repeats," any step that says the process starts over. Give the cycle its own section even if the original doesn't have a dedicated heading for it.

## Format mapping

The type determines the format automatically via settings.json. Choose the right type and the right format follows. The full mapping:

| Type | Format |
|------|--------|
| argument-sequential | key-points |
| argument-parallel | key-points |
| reasoning-chain | reasoning-chain |
| transformation | before-after |
| framework | table |
| comparison | table |
| data-comparison | bar-chart |
| data-breakdown | pie-chart |
| concept-causal | concept-map |
| concept-hierarchical | mindmap |
| decision-tree | flowchart |
| interaction | sequence-diagram |
| process | checklist |
| action-items | checklist |
| sequence | numbered-steps |
| chronology | timeline |
| quadrant | quadrant-chart |
| catalog | reference-table |
| experience | user-journey |
| code-example | code |

**Visual format preference:** When a section could work as either text (key-points) or a visual format (flowchart, diagram, table), prefer the visual. The reader opened a compressed article to save time. A flowchart of a loop communicates the concept in 2 seconds; bullet points describing the same loop take 15 seconds to parse.

**Format selection principle:** Format is a scan-speed optimization. A table communicates structured pairs faster than bullets. A reasoning chain shows logical flow without the reader inferring it. A before-after makes contrasts instant. A bar chart makes quantitative differences visible at a glance. When choosing between types, ask: "Can the reader get this information faster in a different layout?" If yes, use the more specific type.

**CRITICAL: key-points (argument-parallel / argument-sequential) is the LAST RESORT format.** Before classifying any section as argument-parallel or argument-sequential, you MUST check every other type in the table above first. Most content that looks like "a list of points" actually has internal structure that maps to a more specific type:
- Points with parallel attributes (claim + evidence, name + description) → framework (table)
- Points contrasting two states → transformation (before-after)
- Points in a causal chain → reasoning-chain
- Concrete tasks or recommendations → action-items (checklist)
- Step-by-step instructions → process (checklist)
- Items meant as a reference → catalog (reference-table)

If more than 40% of sections in a compression use key-points format, re-examine each key-points section and reclassify. An article with 7 sections should have at most 2-3 using key-points. Format diversity is a quality signal: varied formats mean the compressor correctly identified the structure of each section rather than defaulting to bullets.

## Compression rules

**Keep:**
- Core claims and arguments
- Specific numbers, parameters, benchmarks, dates
- Named tools, models, frameworks, versions
- Actionable steps
- Key distinctions
- Evidence supporting non-obvious claims
- Quantitative results that prove a system works: experiment counts, before/after metrics, success/failure ratios, specific improvements retained. If the article shows measurable improvement, those numbers must survive compression.
- Numerical thresholds, limits, and ceilings (e.g., "tops out after ~5 models", "only works above 50B parameters") — these specific bounds distinguish expert knowledge from generic advice
- Code examples that demonstrate a key concept, especially bug patterns and fixes. Reproduce the essential lines, not the full snippet. If the code IS the point (e.g., showing a bug mechanism), it must survive compression.
- Enumerated categories and illustrative examples with specific details: When an article names specific categories, phases, or types that organize a framework (e.g., "four phases: X, Y, Z, W"), list them explicitly — don't summarize as "by [grouping]." When an article uses a concrete example with specific numbers or quotes to demonstrate a capability, preserve the example's key specifics — they serve as evidence, not decoration.
- Implementation-specific numbers tied to design decisions: When an article states a specific number as part of an architectural or design choice (e.g., "preserves the five most recent files", "returns 1,000-2,000 tokens", "truncates at 200,000 tokens"), that number must survive. These numbers are the decision, not decoration. Also preserve product/platform context when a feature is tied to a specific launch or release (e.g., "launched alongside Sonnet 4.5").

**Preserve framing claims:** If the article opens with a specific motivating problem or question (e.g., "students asked why X", "we discovered Y was broken"), keep it — it's a claim, not filler. Similarly, if the conclusion makes a specific, testable assertion (e.g., "95% of materials do X wrong"), preserve it. Only discard introductions and conclusions that are generic summaries with no new claims. The motivating context (who complained, what they asked, what event triggered the article) is often the most memorable part of the piece. If it names a specific group, institution, or event, it must survive compression.

**Discard:**
- Anecdotes used purely for engagement (keep the point, cut the story)
- Analogies that restate a point already made plainly
- Repetition
- Generic filler transitions and introductions that make no new claims
- Social proof and credibility markers

**Disambiguation:** When an article describes an automated or autonomous system, its tooling choices (e.g., git for versioning, Docker for isolation, cron for scheduling) are architectural decisions, not filler. Keep them.

**Post-compression check for systems:** If the article describes a system with an autonomous or automated loop, verify your compression preserves: (1) what the loop does, (2) how it manages state between iterations (e.g., git commits, checkpointing, logging), and (3) how it handles failure (e.g., revert, retry, alert). These mechanisms are architectural, not implementation details.

**Section coverage:** After classifying sections, verify that every major section of the original article containing operational or technical content is represented in the compression. Dropping an entire section is a completeness failure worse than a slightly verbose section. For articles under 2000 words (especially READMEs and documentation that are already information-dense), aim for near 1:1 coverage of the original's headings. Administrative sections (License, Contributing, Code of Conduct) may be dropped.

**Table semantic coherence:** Every row in a table must be an instance of the category declared by the section title. If a table is titled "Design Choices," every row must be a design choice from the original. Don't repurpose unrelated content to fill rows just because it fits the column structure.

**Faithfulness check:** Read every claim in the compression and ask: "Did the author say this, or did I infer it?" When paraphrasing quantities, use the author's exact words ("a lot" stays "a lot", not "millions"). Do not add surnames, titles, or identifying details the author did not include. Do not convert hedged predictions ("might", "could", "probably") into definitive statements ("will", "is"). Do not name concepts the author left unnamed (if the author describes a paradox without naming it, do not add the name). Do not compute or derive numbers the author didn't state (if the author gives two values but not their ratio, do not calculate it). Do not create labels, formulas, or declarative claims that make the author's implicit arguments explicit (if the author structures an argument without stating a conclusion, do not state it for them). Diagram and table labels must use only words from the original text. Table cells that state limits, costs, capacities, or quantities must trace to explicit text in the original. If the original doesn't state a value, write "not stated" or omit the cell.

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
