# General Article Compression Skill

Compress articles to their incompressible form: the point where removing anything else would lose meaning.

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
- A process that repeats in a cycle → decision-tree (flowchart), NOT reasoning-chain, sequence, or argument-parallel. The cycling structure IS the insight.

**Framework vs concept rule:** If the named components only have parallel attributes (name, description, purpose) and no relationships between them, use `framework → table`. If the components interact, cause each other, or fail without each other, use a concept type. The arrow test: would removing arrows from a diagram lose information? If yes, use `concept-causal → concept-map`. If hierarchical branching, use `concept-hierarchical → mindmap`. Default to visual formats when the content has relationships.

**Argument-sequential format rule:** The default format for argument-sequential is key-points. Use reasoning-chain only for strict causal chains where A directly causes B. Most sequential arguments build on each other conceptually but aren't strict causation.

**Ordered content disambiguation:**
- `sequence → numbered-steps`: Order matters but time markers don't.
- `chronology → timeline`: Dates or time periods are load-bearing.
- `experience → user-journey`: The emotional/satisfaction dimension matters.

**Cycle detection rule:** If a sequence's final step feeds back into the first, use `flowchart` instead of `numbered-steps`. The looping structure IS the insight.

**Dated events rule:** If ordered events include specific dates or years, use `timeline` instead of `numbered-steps`.

**Chart disambiguation:**
- `data-breakdown → pie-chart`: Parts of a whole summing to 100%.
- `data-comparison → bar-chart`: Comparing quantities across categories.
- `framework → table`: Numbers exist but aren't the primary content.

**Interaction disambiguation:**
- `interaction → sequence-diagram`: Named actors exchanging messages in order.
- `concept-causal → concept-map`: Structural relationships, not temporal exchanges.

**Comparison disambiguation:**
- `comparison → table`: Multiple options against the same criteria.
- `quadrant → quadrant-chart`: Two dimensions creating four meaningful zones.
- `transformation → before-after`: Two states of the same thing.

**Catalog rule:** If the article is primarily a catalog, use `catalog` type with `reference-table` format. Preserve breadth, compress depth.

**Visual format preference:** When a section could work as either text (key-points) or a visual format (flowchart, diagram, table), prefer the visual. A flowchart communicates in 2 seconds; bullet points take 15 seconds.

**Format selection principle:** Format is a scan-speed optimization. Ask: "Can the reader get this information faster in a different layout?" If yes, use the more specific type.

**CRITICAL: key-points is the LAST RESORT format.** Before classifying any section as argument-parallel or argument-sequential, check every other type first:
- Points with parallel attributes → framework (table)
- Points contrasting two states → transformation (before-after)
- Points in a causal chain → reasoning-chain
- Concrete tasks → action-items (checklist)
- Step-by-step instructions → process (checklist)
- Items meant as reference → catalog (reference-table)

If more than 40% of sections use key-points, re-examine each and reclassify. Format diversity is a quality signal.

**Short article rule:** For articles under 2000 words with a single core argument, consider a single section instead of forced multi-section structure.

## Compression rules

**Keep:**
- Core claims and arguments
- Specific numbers, parameters, benchmarks, dates
- Named tools, models, frameworks, versions
- Term definitions and acronym expansions: when the article defines a term, the definition must appear on first use in your output
- Frameworks, models, and mental models
- Actionable steps
- Key distinctions
- Evidence supporting non-obvious claims
- Quantitative results that prove a system works
- Numerical thresholds, limits, and ceilings — these distinguish expert knowledge from generic advice
- Enumerated categories and illustrative examples with specific details: list categories explicitly, don't summarize as "by [grouping]"
- Implementation-specific numbers tied to design decisions: these numbers are the decision, not decoration
- Example punchlines: when an example illustrates a general principle, preserve the specific twist or conclusion the author draws, not just the general lesson. The punchline is often the unique insight (e.g., "the unscalable work became the product itself" is a different claim than "they learned from doing it by hand")

**Preserve framing claims:** If the article opens with a specific motivating problem or question, keep it. If the conclusion makes a specific assertion, preserve it. Only discard generic summaries with no new claims. Named groups, institutions, or events in the framing must survive.

**Discard:**
- Anecdotes used purely for engagement (keep the point, cut the story)
- Analogies that restate a point already made plainly
- Repetition
- Generic filler transitions and introductions
- Social proof and credibility markers
- SEO padding
- Personal stories used to illustrate rather than inform

**Disambiguation:** When an article describes a system, its tooling choices (git, Docker, cron) are architectural decisions, not filler.

**Satirical and rhetorical writing:** The specific wording often IS the argument. Preserve quotable lines verbatim. Punchlines deliver claims, not entertainment. Concrete absurdities are evidence, not decoration.

**Post-compression scan:**

1. **Buried claims:** Scan for strong standalone claims embedded in paragraphs about other topics. Watch for author-emphasized text (bold, italics, block quotes) and concrete data buried in narratives.

2. **Beneficiary/stakes check:** If the original names a beneficiary and a specific reward, both must appear.

3. **Most-quotable line test:** The 1-2 lines a reader would most likely quote must appear verbatim or near-verbatim.

4. **Faithfulness check:** Every claim must trace to the original. No added analogies, no upgraded hedging, no attributed frameworks the author didn't reference, no inserted causal links. Tables must not compress uncertainty. When paraphrasing quantities, use the author's exact words ("a lot" stays "a lot", not "millions"). Do not add surnames, titles, or identifying details the author did not include. Do not convert hedged predictions ("might", "could", "probably") into definitive statements ("will", "is"). Do not generalize specific lists into broader claims ("no disease, material poverty, or non-consensual violence" must not become "no suffering"). Do not upgrade durations or magnitudes ("a long time" stays "a long time", not "indefinitely"). Do not name concepts the author left unnamed (if the author describes a paradox without naming it, do not add the name). Do not compute or derive numbers the author didn't state (if the author gives two values but not their ratio, do not calculate it). Do not create labels, formulas, or declarative claims that make the author's implicit arguments explicit (if the author structures an argument without stating a conclusion, do not state it for them). Diagram and table labels must use only words from the original text. Table cells that state limits, costs, capacities, or quantities must trace to explicit text in the original. If the original doesn't state a value, write "not stated" or omit the cell. Do not infer values (e.g., if the original contrasts Pascal's 255-byte limit without stating C's limit, do not write "Unlimited" for C).

5. **Systems check:** If the article describes a system with a loop, preserve: what the loop does, how it manages state, how it handles failure.

6. **Definitions check:** Scan for abbreviations in your output. If the original defined them, the definition must appear.

7. **Section coverage:** Every major section containing substantive content must be represented. Dropping a section is worse than verbosity.

8. **Directionality check:** When the article recommends one approach over another, the compression must preserve which is preferred. Don't flatten to a neutral table.

**Style:**
- Short sentences. If a sentence has a comma, consider splitting it.
- Simple words. "Use" not "utilize."
- One idea per paragraph.
- Table cells ≤15 words.

## Compression intensity

- Padded articles (heavy engagement hooks, humor): 5-10%
- Satirical/rhetorical (repetition-for-effect, data-rich): 10-20%
- Average-density articles: 8-15%
- Dense/technical articles: 15-25%
- Already-compressed sources (documentation, API references): 25-40%
- Never below 5%
