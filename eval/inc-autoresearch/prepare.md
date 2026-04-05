# Prepare: Immutable Constants, Corpus, and Evaluation Protocol

DO NOT MODIFY THIS FILE during autoresearch. This is the equivalent of Karpathy's `prepare.py`. It defines the fixed evaluation, data, and constants. Only the human modifies this file between sessions.

## Faithfulness Constraint

This is non-negotiable and applies to ALL compressions regardless of what inc-skill.md says:

Every claim in a compression must trace to a specific sentence in the original article. No external knowledge. No inferring. No gap-filling. A factually correct claim not in the original is a hallucination. If inc-skill.md ever contains a rule that conflicts with this constraint, this constraint wins.

## Evaluation Protocol

### Metric: Accuracy (core ideas captured)

For each article in the corpus, a set of **core ideas** is pre-defined below. These are the answer key. Each core idea is a specific, testable claim from the original article.

### Scoring procedure

For each core idea, ask: **"Is this specific idea present in the compression without distortion?"**

- **Present (1)**: The compression contains this idea with its key specific detail preserved. Paraphrasing is fine if the specific detail survives.

- **Absent (0)**: The idea is missing, or present but distorted (key detail lost, claim reversed, hedging removed, specificity reduced to vagueness).

**Article score** = (ideas present / total ideas) x 100

**Corpus score** = average of all article scores

### Evaluation independence

Evaluation MUST be performed by a separate `claude -p` call. The evaluator sees only the original article text, the compressed output, and the core ideas checklist. It has no knowledge of the mutation, the compression reasoning, or previous experiment scores. This prevents self-evaluation bias.

### Keep/revert threshold

- **KEEP** if corpus score improved by >= 2 points over the **frozen baseline** (experiment #0)
- **REVERT** if corpus score did not improve by >= 2 points over frozen baseline
- **REVERT** (regression gate) if any single article lost more than 2 core ideas compared to its **frozen baseline** score, regardless of corpus average

Comparisons are always against the frozen baseline, not the previous experiment. This prevents score drift.

### Precision constraint (hallucination check)

After scoring the recall checklist, evaluate.sh runs a second check: for each claim in the compressed output, is it traceable to the original article?

- **REVERT** if total corpus hallucinations increase by >= 2 compared to the **frozen baseline's** total hallucination count
- A hallucination is any claim that: states a fact not in the original (even if factually correct), adds a framework or term the author didn't use, upgrades hedged language, or adds causal links the author left ambiguous

### Compression ratio constraint

evaluate.sh calculates `compressed_words / original_words` deterministically (not by the LLM).

- **REVERT** if any article's compression ratio falls outside 5-40%

## Results format

Tab-separated file: `results.tsv`

Header row:
```
exp	commit	mutation	do-things-that-dont-scale	mean-people-fail	ai-revolution	what-makes-you-you	never-rewrite	most-important-century	seven-strange-questions	what-you-cant-say	back-to-basics	how-to-make-wealth	avg	hallucinations	verdict
```

## Corpus

### Article 1: Do Things that Don't Scale

- **ID**: do-things-that-dont-scale
- **File**: corpus/do-things-that-dont-scale.txt
- **Source**: paulgraham.com/ds.html
- **Author**: Paul Graham
- **Words**: ~4,800
- **Density**: average
- **Why included**: Medium argument essay with standalone claims buried in narrative. Tests post-compression scan for missed claims.

**Core ideas (17):**

1. Startups take off because founders make them take off, not spontaneously
2. Compound growth: 10%/week = 14K users in a year
3. Manual recruiting: go get users one at a time
4. Collison installation: set users up on the spot instead of just asking
5. Extraordinary attention to early users (Wufoo hand-written thank-you notes)
6. Make the experience insanely great, even with a buggy product
7. Start in deliberately narrow market (Facebook: Harvard only first)
8. Pick one user, build for them, then generalize (consulting approach)
9. Do manually what you'll automate later (Stripe signed up merchants by hand)
10. Big launches don't work. Users come gradually, not from a single announcement
11. Partnerships don't work for early-stage startups
12. Think of startup ideas as vectors: what you build + the unscalable initial tactic
13. The unscalable things should change company DNA permanently
14. Never seen a startup lured down a blind alley by trying too hard to make initial users happy
15. Among companies, the best early adopters are usually other startups
16. Hardware startups get an unfair advantage from personal attention (Pebble, Meraki)
17. Meraki: doing things that don't scale can become the product itself

### Article 2: Mean People Fail

- **ID**: mean-people-fail
- **File**: corpus/mean-people-fail.txt
- **Source**: paulgraham.com/mean.html
- **Author**: Paul Graham
- **Words**: ~2,100
- **Density**: average
- **Why included**: Short article, single argument. Tests short-article rule and forced fragmentation.

**Core ideas (6):**

1. Most successful people aren't mean — meanness and success inversely correlate
2. Meanness impairs thinking — fighting consumes mental energy on situation-specific tricks
3. Mean founders can't attract top talent — best people have options
4. Successful founders driven by world-improvement, not money — money-driven ones take acquisitions
5. Historical shift: success was zero-sum (resource control) → now positive-sum (innovation)
6. Civil peace enables creation — people must feel what they create can't be stolen

### Article 3: The AI Revolution: Road to Superintelligence

- **ID**: ai-revolution
- **File**: corpus/ai-revolution.txt
- **Source**: waitbutwhy.com/2015/01/artificial-intelligence-revolution-1.html
- **Author**: Tim Urban
- **Words**: ~8,000
- **Density**: padded
- **Why included**: Longest padded article. Claim reversal bug discovered here. Tests framework extraction from narrative.

**Core ideas (12):**

1. Three AI levels: ANI (narrow), AGI (general), ASI (superintelligent)
2. Law of Accelerating Returns: progress is exponential, not linear
3. Die Progress Unit (DPU): timespan of change that would shock a time-traveler, compressing over history
4. Hardware nearly sufficient for AGI-level computation (Tianhe-2 exceeds estimated brain capacity)
5. Software approaches: brain emulation, genetic algorithms, self-improving systems
6. Intelligence explosion: AGI → ASI could happen in hours via recursive self-improvement
7. Median expert estimate for AGI: ~2040
8. Three cognitive biases prevent accurate prediction: linear thinking, narrow time windows, experience-based skepticism
9. ASI would have god-like capabilities (atomic-level control)
10. The key question: will superintelligent AI be aligned with human values?
11. This is humanity's most important challenge
12. Exponential curves look flat at the beginning — we're on the flat part now

### Article 4: What Makes You You?

- **ID**: what-makes-you-you
- **File**: corpus/what-makes-you-you.txt
- **Source**: waitbutwhy.com/2014/12/what-makes-you-you.html
- **Author**: Tim Urban
- **Words**: ~3,800
- **Density**: average
- **Why included**: Philosophical/concept-heavy. Tests concept classification and sequential argument with thought experiments.

**Core ideas (9):**

1. Body Theory fails: cells, organs, even DNA are replaceable without losing identity (identical twins share DNA but aren't the same person)
2. Brain Theory: wherever your brain goes, you go (brain swap thought experiment)
3. Data Theory: you are your brain's data (memories, personality), not the physical matter
4. Teletransporter problem: a perfect molecular copy with all your data isn't you — something was lost
5. Split Brain problem breaks the Brain Theory (donate half your brain, both copies wake up with your identity)
6. Gradual cell replacement paradox: replacing cells one-by-one never kills you, but at 100% you're identical to a copy we said wasn't you
7. Continuity is the key thread — you're not a fixed thing but a story/progression that evolves over time
8. The soul might refer to the thread of continuity across a lifetime of change, not a supernatural entity
9. The rigid self we cling to might be an illusion — recognizing this could reduce suffering (Buddhist view)

### Article 5: Things You Should Never Do, Part I

- **ID**: never-rewrite
- **File**: corpus/never-rewrite.txt
- **Source**: joelonsoftware.com/2000/04/06/things-you-should-never-do-part-i/
- **Author**: Joel Spolsky
- **Words**: ~2,100
- **Density**: average
- **Why included**: Short tech opinion from validation set. Tests generalization beyond PG essays.

**Core ideas (6):**

1. Rewriting software from scratch is one of the worst strategic mistakes
2. Netscape rewrote from scratch, lost 3 years of market position, and collapsed
3. It's harder to read code than to write it — this bias drives unnecessary rewrites
4. Old code contains accumulated bug fixes, edge case solutions, and hard-won knowledge
5. Three categories of mess: architectural (refactor), inefficient (optimize), aesthetic (clean up) — none require full rewrite
6. Incremental improvement beats starting over

### Article 6: Most Important Century

- **ID**: most-important-century
- **File**: corpus/most-important-century.txt
- **Source**: cold-takes.com/most-important-century/
- **Author**: Holden Karnofsky
- **Words**: ~3,500
- **Density**: dense
- **Why included**: Already-dense summary. Tests compression intensity targets on content that's already compressed.

**Core ideas (7):**

1. The 21st century could be the most important ever for humanity, through transformative AI
2. AI automating innovation creates a feedback loop that compresses radical change from centuries to decades
3. Biological anchors forecasting suggests transformative AI has better-than-even odds this century
4. Technology could enable digital people (conscious software entities) and galaxy-spanning outcomes
5. Even conservative timelines place us in an extraordinary era — fastest-growing time in human history
6. Civilization is inadequately prepared despite the potential stakes
7. The right response is vigilance and positioning, not panic — take robustly good actions now

### Article 7: 7 Strange Questions That Help You Find Your Life Purpose

- **ID**: seven-strange-questions
- **File**: corpus/seven-strange-questions.txt
- **Source**: markmanson.net/life-purpose
- **Author**: Mark Manson
- **Words**: ~3,500
- **Density**: padded
- **Why included**: Listicle/framework. Tests table formatting, cell word limits, and catalog-like content within a framework.

**Core ideas (8):**

1. Life purpose isn't cosmic destiny — it's finding what struggles feel meaningful
2. Shit Sandwich: what difficulties are you willing to endure? Your competitive advantage.
3. Childhood Self: what passions did you abandon in adolescence?
4. Flow State: what absorbs you completely?
5. Embarrassment: what scares you socially? Fear points toward what matters.
6. World-Changing: what problem bigger than you do you care about?
7. Hypothetical Day: where would you spend time if you had to leave daily?
8. Action reveals purpose — meaning emerges from doing, not introspection

### Article 8: What You Can't Say

- **ID**: what-you-cant-say
- **File**: corpus/what-you-cant-say.txt
- **Source**: paulgraham.com/say.html
- **Author**: Paul Graham
- **Words**: ~5,500
- **Density**: average
- **Why included**: Rhetorical/argumentative essay about moral fashions. Tests quotable-line preservation, rhetorical framing, and specific historical examples embedded in argument.

**Core ideas (11):**

1. Moral fashions exist like clothing fashions but are more dangerous — violating them can get you fired, ostracized, imprisoned, or killed
2. The Conformist Test: if you have no opinions you'd be reluctant to express, you probably just think what you're told
3. Statements that make people maddest are those they worry might be true (Galileo example)
4. "Heresy" labels (blasphemy, inappropriate, divisive) shoot down ideas before examining truth — when someone attacks a statement as "divisive" instead of "false," pay attention
5. Time and space comparison: diff present ideas against past cultures and other societies to find what we're wrong about
6. Moral fashions created deliberately by groups poised between weakness and power — strong enough to enforce taboos but weak enough to need them
7. Fashion adoption has two waves: early adopters driven by ambition, then a larger group driven by fear
8. Unthinkable thoughts benefit work — great work grows from overlooked ideas; training to think outside the box makes innovation easier
9. Practical advice: don't say heretical thoughts; draw a sharp line between thoughts and speech ("pensieri stretti & il viso sciolto")
10. Counter-strategies: ratchet debate up one level of abstraction, use metaphor (Arthur Miller's "The Crucible" vs HUAC), or humor — zealots can't reply to jokes
11. Open-mindedness is invisible to those who lack it — when people are bad at it, they don't know it

### Article 9: Back to Basics

- **ID**: back-to-basics
- **File**: corpus/back-to-basics.txt
- **Source**: joelonsoftware.com/2001/12/11/back-to-basics/
- **Author**: Joel Spolsky
- **Words**: ~3,200
- **Density**: dense
- **Why included**: Technical article with code examples, specific algorithms, and performance analysis. Tests code preservation, numerical claims, and technical argument chains in non-AI context.

**Core ideas (10):**

1. Biggest architectural mistakes come from weak understanding of lowest-level fundamentals
2. C strings (ASCIZ: null-terminated) can't know their length without scanning and can't contain zeros — inherited from PDP-7
3. Repeated strcat creates Shlemiel the Painter's algorithm: O(n-squared) because each call rescans from the beginning
4. Fix: mystrcat returns pointer to end of string, making concatenation O(n) instead of O(n-squared)
5. Pascal strings store length in first byte — length check is one instruction instead of a loop; Excel uses them internally (why strings limited to 255 bytes, why Excel is fast)
6. Buffer overflows from incorrect memory allocation were the number one cause of hacks and worms
7. malloc walks a free chain and occasionally does slow cleanup — same performance characteristic as garbage collection
8. Smart allocation: powers of 2 minimize fragmentation (wastes at most 50%); doubling on realloc means at most lg(n) reallocations
9. Relational databases use fixed-length rows so next-record is one CPU instruction (pointer += recordsize); XML requires parsing, hundreds of instructions per record
10. CS students should start with C and build up from the CPU, not start with Java — generations of graduates create Shlemiel algorithms without realizing it

### Article 10: How to Make Wealth

- **ID**: how-to-make-wealth
- **File**: corpus/how-to-make-wealth.txt
- **Source**: paulgraham.com/wealth.html
- **Author**: Paul Graham
- **Words**: ~9,000
- **Density**: average
- **Why included**: Longest essay in corpus. Many specific economic claims, named frameworks (Pie Fallacy, measurement + leverage), and numerical arguments. Tests preservation of specific numbers and multi-section argument structure.

**Core ideas (14):**

1. Startup = compressing your working life into a few years; 2x hours, 3x productivity, no management overhead = roughly 36x more productive (multiplier between 10 and 100)
2. Conservation law: to make a million dollars, endure a million dollars' worth of pain
3. Money is not wealth — wealth is stuff we want; money is a medium of exchange, a side effect of specialization
4. The Pie Fallacy: wealth is not a fixed pie — you can create new wealth
5. Getting rich requires both measurement and leverage — measurement alone (piecework) or leverage alone isn't enough
6. Smallness = measurement: in a 10-person startup, you're within a factor of 10 of measuring individual contribution
7. Technology = leverage: new techniques multiply value across all users — difference between a startup and a barber shop
8. "Run upstairs" strategy: deliberately choose harder problems because difficulty is harder for large competitors to follow
9. Startup payoff has high variance: if the mean is 30x, the median is probably zero — most startups tank
10. Acquirers buy users, not technology — users are the only real proof you've created wealth
11. Fear of loss motivates acquirers more than hope of gain
12. Rule of law enabled wealth creation: medieval European merchants could protect fortunes from feudal lords, which caused industrialization
13. Bill Gates/Microsoft required luck (IBM's DOS licensing blunder) — outlier billionaire fortunes involve a large random factor
14. Governments that forbid wealth accumulation effectively decree that you work slowly — Soviet Union example

### Adding articles to the corpus

To add an article:
1. Fetch the full article text and save to `corpus/<article-id>.txt`
2. Add an entry to this file following the format above
3. Define 6-17 core ideas with testable specificity
4. Add the article's column to the results.tsv header
5. Re-run baseline (experiment #0) to establish scores for all articles including the new one
