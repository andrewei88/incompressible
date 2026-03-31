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
- Safety and reversibility mechanisms (rollback, revert, undo, checkpointing) in autonomous or automated systems

**Discard:**
- Anecdotes used purely for engagement (keep the point, cut the story)
- Analogies that restate a point already made plainly
- Repetition
- Filler transitions and introductions
- Social proof and credibility markers

**Style:**
- Short sentences. If a sentence has a comma, consider splitting it.
- Simple words. "Use" not "utilize."
- One idea per paragraph.

## Compression intensity

- Padded articles (heavy engagement hooks, humor): 5-10%
- Average-density articles: 8-15%
- Dense/technical articles: 15-25%
- Never below 5%
