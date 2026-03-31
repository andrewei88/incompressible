# Prepare: Immutable Constants, Corpus, and Evaluation Protocol

DO NOT MODIFY THIS FILE during autoresearch. This is the equivalent of Karpathy's `prepare.py`. It defines the fixed evaluation, data, and constants. Only the human modifies this file between sessions.

## Faithfulness Constraint

This is non-negotiable and applies to ALL compressions regardless of what ai-skill.md says:

Every claim in a compression must trace to a specific sentence in the original article. No external knowledge. No inferring. No gap-filling. A factually correct claim not in the original is a hallucination. If ai-skill.md ever contains a rule that conflicts with this constraint, this constraint wins.

## Evaluation Protocol

### Metric: Accuracy (core ideas captured)

For each article in the corpus, a set of **core ideas** is pre-defined below. These are the answer key. Each core idea is a specific, testable claim from the original article.

### Scoring procedure

For each core idea, ask: **"Is this specific idea present in the compression without distortion?"**

- **Present (1)**: The compression contains this idea with its key specific detail preserved. Paraphrasing is fine if the specific detail survives. Example: core idea says "Adam with lr 3e-4 is a safe default." Compression says "start with Adam at 3e-4" = present. Compression says "use a reasonable learning rate" = absent (lost the specific claim).

- **Absent (0)**: The idea is missing, or present but distorted (key detail lost, claim reversed, hedging removed, specificity reduced to vagueness).

**Article score** = (ideas present / total ideas) x 100

**Corpus score** = average of all article scores

### Evaluation independence

Evaluation MUST be performed by a separate Agent call. The evaluator sees only the original article text, the compressed output, and the core ideas checklist. It has no knowledge of the mutation, the compression reasoning, or previous experiment scores. This prevents self-evaluation bias.

### Keep/revert threshold

- **KEEP** if corpus score improved by >= 2 points over the **frozen baseline** (experiment #0)
- **REVERT** if corpus score did not improve by >= 2 points over frozen baseline
- **REVERT** (regression gate) if any single article lost more than 2 core ideas compared to its **frozen baseline** score, regardless of corpus average

Comparisons are always against the frozen baseline, not the previous experiment. This prevents score drift.

These thresholds can be adjusted by the human between sessions based on observed noise levels.

### Precision constraint (hallucination check)

After scoring the recall checklist, evaluate.sh runs a second check: for each claim in the compressed output, is it traceable to the original article?

- **REVERT** if total corpus hallucinations increase by >= 2 compared to the **frozen baseline's** total hallucination count
- A hallucination is any claim that: states a fact not in the original (even if factually correct), adds a framework or term the author didn't use, upgrades hedged language, or adds causal links the author left ambiguous

This is a relative threshold, not absolute. Borderline hallucinations (author attribution, structural labeling) fluctuate between runs. A mutation that causes a real precision regression will show up as a clear increase across the corpus (>=2), not a ±1 fluctuation. The primary defense against hallucination is the faithfulness instruction in compress.sh (immutable), not ai-skill.md rules.

### Compression ratio constraint

evaluate.sh calculates `compressed_words / original_words` deterministically (not by the LLM).

- **REVERT** if any article's compression ratio falls outside 5-40%
- Below 5% means the compression is too aggressive (likely dropping content)
- Above 40% means the compression isn't compressing enough (likely reproducing too much)

This constraint prevents the "reproduce everything" degenerate solution where recall is maximized by minimizing compression.

## Results format

Tab-separated file: `results.tsv`

Header row:
```
exp	commit	mutation	autoresearch	karpathy-recipe	prompt-engineering	lora-tips	karpathy-backprop	llm-agents	multi-agent-research	context-engineering	llm-patterns	avg	hallucinations	verdict
```

Each row: experiment number (0 = baseline), short commit hash, brief mutation description, per-article accuracy scores, average score, KEEP/REVERT/BASELINE.

## Corpus

### Article 1: Autoresearch

- **ID**: autoresearch
- **File**: corpus/autoresearch.txt
- **Source**: github.com/karpathy/autoresearch (README)
- **Author**: Andrej Karpathy
- **Words**: ~1,223
- **Density**: dense (technical documentation, already compressed)
- **Why included**: Functional/meta, short, dense. Tests compression of technical content with specific tools and parameters.

**Core ideas (8):**

1. The system enables autonomous AI agents to optimize LLM training overnight without human intervention. [Must convey autonomy and overnight operation]
2. Three files: prepare.py (immutable constants, eval, data loading), train.py (the only file agents edit), program.md (human-written instructions for agents). [Must name all three files with their roles]
3. Fixed 5-minute training budget per experiment (wall-clock time, excluding startup). This enables ~12 experiments/hour, ~100 overnight. [Must state the 5-minute budget and throughput numbers]
4. Single optimization metric: val_bpb (validation bits per byte), lower is better, vocabulary-size-independent. [Must name val_bpb and state lower is better]
5. The agent modifies only train.py: architecture, optimizer, hyperparameters, batch size, model dimensions. prepare.py is read-only. [Must state the single-file constraint]
6. Autonomous loop: modify code, commit, train, evaluate, record, keep or revert. Loop continues indefinitely without pausing for human. [Must describe the loop and its autonomous nature]
7. The single-file design constraint (agent edits only train.py) exists because it keeps scope manageable and diffs reviewable. [Must state at least one rationale for the single-file constraint: manageable scope, reviewable diffs, or easy revertibility]
8. Single GPU, PyTorch only, minimal dependencies. Self-contained by design. [Must convey the simplicity/minimalism]

### Article 2: A Recipe for Training Neural Networks

- **ID**: karpathy-recipe
- **File**: corpus/karpathy-recipe.txt
- **Source**: karpathy.github.io/2019/04/25/recipe/
- **Author**: Andrej Karpathy
- **Words**: ~3,833
- **Density**: average (blog post with analogies and examples, but high information density)
- **Why included**: Sequential argument structure with specific debugging techniques. Tests compression of a step-by-step methodology with concrete, actionable tips.

**Core ideas (10):**

1. Neural net training is a "leaky abstraction": unlike standard software (e.g., the requests library), NNs are not plug-and-play. Libraries hide complexity but NNs require understanding internals to work. [Must reference the "leaky abstraction" concept]
2. Neural net training fails silently: misconfigurations don't throw exceptions but produce subtly worse results. Examples include flipped labels during augmentation, off-by-one in autoregressive models, clipping loss instead of gradients. [Must give at least one specific silent failure example]
3. The recipe builds simple-to-complex, validating hypotheses at every step. Never introduce a lot of "unverified" complexity at once. [Must convey the incremental validation approach]
4. Step 1 is data inspection, not model code. Spend hours scanning thousands of examples for duplicates, corrupted labels, imbalances, biases, and outliers before touching any model. [Must state data inspection comes before model code]
5. Step 2: Set up end-to-end training/evaluation skeleton with dumb baselines (linear classifier or tiny ConvNet). Fix random seed, disable augmentation, verify loss at init equals -log(1/n_classes). [Must mention at least two of: random seed, init loss verification, dumb baseline]
6. Overfit a single batch (as few as two examples) to verify pipeline correctness. If the model can't reach zero loss on one batch, there's a bug. [Must state the single-batch overfit test]
7. Use backprop to chart dependencies: set loss to sum of all outputs of example i, run backward pass, verify non-zero gradient only on the i-th input. Catches batch dimension mixing bugs from incorrect use of view vs transpose/permute. [Must describe this specific debugging technique]
8. Step 3: First overfit (focus on training loss), then regularize. "Don't be a hero": copy paste architecture from the most related paper (e.g., ResNet-50). Adam with learning rate 3e-4 as safe default. [Must include "don't be a hero" and Adam 3e-4]
9. Best regularization is more real training data: the only guaranteed way to monotonically improve a well-configured NN. Ensembles also work but top out after ~5 models. [Must state more data is the best regularizer]
10. Use random search over grid search for hyperparameter tuning: NNs are more sensitive to some parameters than others, so sampling broadly beats covering fixed grid points. [Must explain why random beats grid]

### Article 3: Prompt Engineering

- **ID**: prompt-engineering
- **File**: corpus/prompt-engineering.txt
- **Source**: lilianweng.github.io/posts/2023-03-15-prompt-engineering/
- **Author**: Lilian Weng
- **Words**: ~4,668
- **Density**: dense (research survey with citations, examples, and mathematical formulations)
- **Why included**: Catalog/taxonomy structure with many named techniques. Tests compression of a reference-style article where preserving technique names and distinctions matters.

**Core ideas (10):**

1. Prompt engineering steers LLM behavior without updating model weights. It is an empirical science; methods vary significantly across models, requiring experimentation. [Must state "without updating weights" and the empirical nature]
2. Few-shot outperforms zero-shot by providing input-output demonstrations, but costs more tokens and may hit context length limits. Choice of examples, format, and order dramatically affects performance. [Must contrast the two with at least one tradeoff]
3. Three biases in few-shot: majority label bias (unbalanced label distribution), recency bias (model repeats the last label), common token bias (model favors frequent tokens). Mitigation: calibrate probabilities to uniform when input is N/A. [Must name at least two of the three biases]
4. Few-shot example selection should use semantic similarity (k-NN in embedding space). Example ordering matters and the same order works differently across models. [Must mention semantic similarity for selection]
5. Chain-of-Thought (CoT) prompting generates step-by-step reasoning chains before the answer. Two types: few-shot CoT (demonstrations with reasoning chains) and zero-shot CoT ("Let's think step by step"). Benefits are more pronounced for complex tasks with large models (>50B parameters). [Must name both CoT types and the >50B threshold]
6. Self-consistency sampling: sample multiple outputs at temperature > 0, then select by majority vote. Improves reasoning accuracy over single-sample CoT. [Must describe the sample-then-vote mechanism]
7. Tree of Thoughts extends CoT by exploring multiple reasoning paths at each step, creating a tree structure searched via BFS or DFS, with states evaluated by classifier or majority vote. [Must describe the tree structure and search]
8. APE (Automatic Prompt Engineer) searches over model-generated instruction candidates, filters by score function, and uses iterative Monte Carlo search to find optimal prompts. [Must name APE and describe the search approach]
9. Tool-augmented LMs (Toolformer, TALM) teach models to call external APIs (calculator, search engine, QA system, translation, calendar). Toolformer uses self-supervised filtering: keep API calls only if they help predict future tokens. [Must name at least one system and the self-supervised filtering criterion]
10. Retrieval augmentation for knowledge beyond pretraining cutoff: retrieve documents, split into paragraphs, rank by TF-IDF similarity, include top result in prompt. Even "internal retrieval" (generating knowledge before answering) improves performance. [Must describe the retrieve-then-prompt pipeline]

### Article 4: Practical Tips for Finetuning LLMs Using LoRA

- **ID**: lora-tips
- **File**: corpus/lora-tips.txt
- **Source**: Sebastian Raschka's blog
- **Author**: Sebastian Raschka
- **Words**: ~1,228
- **Density**: dense (technical recommendations with specific benchmarks and hyperparameters)
- **Why included**: Short, dense, highly specific. Tests compression of numerical claims, hyperparameter recommendations, and comparative benchmarks.

**Core ideas (8):**

1. LoRA decomposes weight updates into two low-rank matrices (ΔW ≈ AB), dramatically reducing parameters. Example: 200M-parameter matrix needs only 240K parameters at rank-8 (830x reduction). [Must state the decomposition and give at least one specific reduction number]
2. QLoRA (4-bit quantization + LoRA) achieves 33% memory savings but 39% runtime increase. Standard LoRA: 1.85hrs/21.33GB vs QLoRA: 2.79hrs/14.18GB for a 7B model. [Must state the memory/speed tradeoff with numbers]
3. Multi-epoch training hurts instruction finetuning. Training over 50k Alpaca examples twice declined performance due to overfitting. Same for the 1k LIMA dataset. [Must state that multiple epochs hurt, not help]
4. Optimizer choice (AdamW vs SGD) matters little at small LoRA ranks because trainable parameters are tiny (4.19M at rank-8 = 16.78MB). Difference grows at larger ranks like r=256. [Must convey that optimizer matters less at small ranks]
5. Enable LoRA across all layers, not just Key/Value matrices. Going from K/V only (4.2M params) to all layers (20.3M params, 5x increase) improves performance. Memory rises from 14.18GB to 16.62GB. [Must state the all-layers recommendation with at least one number]
6. LoRA scaling uses alpha/r ratio. Convention: alpha = 2x rank. But r=256 with alpha=128 (0.5x scaling) outperformed the 2x rule in some cases. Optimal requires experimentation. [Must mention the alpha/rank relationship and that 2x isn't always optimal]
7. Dataset quality over quantity: LIMA (1,000 curated examples) outperforms Alpaca (50,000 synthetic/ChatGPT-generated examples) at same model size. [Must name both datasets with approximate sizes]
8. Finetuning teaches instruction-following, not domain knowledge. Knowledge comes from pretraining. Models finetuned on Alpaca performed worse on arithmetic, suggesting they "unlearned" absent capabilities. [Must state the instruction-following vs knowledge distinction]

### Article 5: Yes You Should Understand Backprop

- **ID**: karpathy-backprop
- **File**: corpus/karpathy-backprop.txt
- **Source**: karpathy.medium.com/yes-you-should-understand-backprop-e2f06eab496b
- **Author**: Andrej Karpathy
- **Words**: ~1,581
- **Density**: average (blog post with code examples and mathematical reasoning)
- **Why included**: Code-heavy with numpy examples. Tests preservation of code snippets, mathematical expressions (z*(1-z), eigenvalues), and bug descriptions with before/after fixes.

**Core ideas (8):**

1. Central thesis: backpropagation is a leaky abstraction. You cannot just stack layers and trust autograd to "magically make them work." Understanding the backward pass is essential, not optional. [Must state "leaky abstraction" and the practical necessity argument]
2. Vanishing gradients on sigmoids: if weight matrix W is initialized too large, sigmoid outputs saturate to 0 or 1, making local gradient z*(1-z) equal zero. Gradient vanishes from that point due to chain rule multiplication. [Must explain the saturation mechanism with z*(1-z)]
3. Sigmoid's local gradient z*(1-z) has a maximum of 0.25 (at z=0.5), so gradient magnitude diminishes by at least one quarter through each sigmoid gate. Lower layers train much slower than higher ones. [Must state the 0.25 maximum and its consequence]
4. Dead ReLUs: if a neuron is clamped to zero (doesn't fire), its weights get zero gradient permanently. Irrecoverable. Can find a large fraction (e.g. 40%) of neurons dead in a trained network. [Must describe the permanent death mechanism and give the 40% example]
5. Exploding gradients in RNNs: gradient is repeatedly multiplied by the same recurrence matrix Whh. If largest eigenvalue > 1, gradients explode; if < 1, they vanish. Fix: gradient clipping or use LSTM. [Must mention the eigenvalue reasoning and at least one fix]
6. DQN clipping bug (spotted in the wild): tf.clip_by_value on the Q-delta has zero local gradient outside the clip range, silently killing learning. The authors intended to clip the gradient for robustness but clipped the value instead. Fix: use Huber loss. [Must describe the bug mechanism and the Huber loss fix]
7. The article's motivation: CS231n students at Stanford asked why they must write backward passes manually when frameworks like TensorFlow compute them automatically. [Must reference CS231n and the student complaint]
8. Conclusion: 95% of backpropagation materials present it wrong, filling pages with mechanical math instead of emphasizing intuition. [Must state the 95% claim and the intuition vs. mechanical math distinction]

### Article 6: LLM Powered Autonomous Agents

- **ID**: llm-agents
- **File**: corpus/llm-agents.txt
- **Source**: lilianweng.github.io/posts/2023-06-23-agent/
- **Author**: Lilian Weng
- **Words**: ~6,514
- **Density**: dense (research survey with citations, system prompts, and algorithm descriptions)
- **Why included**: Longest article in corpus. Complex multi-section taxonomy with named systems, code/prompt examples, and comparative evaluations. Tests compression at scale and preservation of system names with distinguishing details.

**Core ideas (10):**

1. LLM-powered autonomous agent systems have three key components: Planning, Memory, and Tool Use, with the LLM as the core controller ("brain"). [Must name all three components]
2. Task decomposition methods: Chain of Thought (CoT, "think step by step"), Tree of Thoughts (explores multiple reasoning paths via BFS/DFS at each step), and LLM+P (outsources planning to an external classical planner using PDDL). [Must name at least two methods with a distinguishing detail each]
3. ReAct integrates reasoning and acting by extending the action space: Thought/Action/Observation format. Reflexion adds dynamic memory and self-reflection with binary reward signals to improve iteratively. [Must describe ReAct's format and Reflexion's memory/self-reflection mechanism]
4. Memory types map to human cognition: sensory memory maps to embeddings, short-term memory maps to in-context learning (limited by finite context window), long-term memory maps to external vector store with fast retrieval. [Must give at least two of the three mappings]
5. MIPS (Maximum Inner Product Search) algorithms for fast vector retrieval include LSH (locality-sensitive hashing), ANNOY (random projection trees), HNSW (hierarchical small-world graphs), FAISS (vector quantization with clustering), and ScaNN (anisotropic vector quantization). [Must name at least three algorithms with a distinguishing detail each]
6. MRKL is a neuro-symbolic architecture that routes queries to expert modules (neural or symbolic, e.g. math calculator, weather API). Experiment showed LLMs struggle to extract correct arguments for basic arithmetic. [Must describe the routing architecture and the arithmetic finding]
7. HuggingGPT uses ChatGPT as task planner to select models from HuggingFace in a 4-stage pipeline: task planning, model selection, task execution, response generation. [Must name HuggingGPT and at least 3 of the 4 stages]
8. ChemCrow uses 13 expert-designed chemistry tools. Key finding: LLM-based evaluation rated ChemCrow and GPT-4 as nearly equivalent, but human expert evaluation showed ChemCrow significantly outperformed GPT-4. This highlights the unreliability of LLM self-evaluation in expert domains. [Must state the divergence between LLM and human evaluation]
9. Generative Agents: 25 virtual characters in a sandbox environment, each controlled by an LLM agent. Architecture includes memory stream (long-term log), retrieval model (relevance, recency, importance), and reflection mechanism. Produced emergent social behavior. [Must describe the architecture and mention emergent behavior]
10. Three key challenges: (1) finite context length limits historical information and instruction detail, (2) long-term planning and task decomposition remain difficult (LLMs struggle to adjust plans on errors), (3) natural language interface is unreliable (formatting errors, occasional refusal to follow instructions). [Must name at least two of the three challenges with specifics]

### Article 7: How We Built Our Multi-Agent Research System

- **ID**: multi-agent-research
- **File**: corpus/multi-agent-research.txt
- **Source**: anthropic.com/engineering/multi-agent-research-system
- **Author**: Anthropic (Jeremy Hadfield, Barry Zhang, Kenneth Lien, Florian Scholz, Jeremy Fox, Daniel Ford)
- **Words**: ~3,583
- **Density**: average-dense (engineering blog with specific metrics, architecture details, and failure modes)
- **Why included**: Company engineering blog with systems architecture, specific benchmarks, named deployment patterns. Tests systems check rule, tooling disambiguation, and preservation of scaling rules with numbers.

**Core ideas (10):**

1. Multi-agent research with Claude Opus 4 as lead and Claude Sonnet 4 subagents outperformed single-agent Claude Opus 4 by 90.2% on an internal research eval. [Must mention 90.2% and the specific model pairing: Opus 4 lead, Sonnet 4 subagents]
2. Three factors explained 95% of performance variance on BrowseComp, with token usage alone explaining 80%, and the other two being number of tool calls and model choice. [Must mention BrowseComp, 95%, and 80% token usage figure]
3. Upgrading to Claude Sonnet 4 produced a larger performance gain than doubling the token budget on Claude Sonnet 3.7. [Must mention both Sonnet 4 and Sonnet 3.7 and the specific comparison: model upgrade beats 2x tokens]
4. Agents use roughly 4x more tokens than chat interactions, and multi-agent systems use roughly 15x more tokens than chats. [Must mention both the 4x and 15x multipliers]
5. The system uses scaling rules embedded in prompts: simple fact-finding needs 1 agent with 3-10 tool calls, direct comparisons need 2-4 subagents with 10-15 calls each, and complex research uses 10+ subagents. [Must include the specific numeric tiers]
6. A tool-testing agent that used flawed MCP tools dozens of times and rewrote their descriptions achieved a 40% decrease in task completion time for future agents. [Must mention 40% decrease and the mechanism: agent rewrites tool descriptions by testing them]
7. Two kinds of parallelization were introduced: the lead agent spawns 3-5 subagents in parallel, and subagents use 3+ tools in parallel, cutting research time by up to 90% for complex queries. [Must mention 90% time reduction and both parallelization levels]
8. The LeadResearcher saves its plan to Memory because the context window truncates at 200,000 tokens, and a CitationAgent processes documents after research to attribute claims to sources. [Must mention 200,000 token threshold and the CitationAgent as a distinct agent]
9. Rainbow deployments are used to avoid disrupting running agents during updates, gradually shifting traffic from old to new versions while both run simultaneously. [Must name "rainbow deployments" specifically]
10. The top use case for Research is developing software systems across specialized domains at 10%, followed by professional/technical content optimization at 8% and business growth strategies at 8%. [Must include at least two category percentages]

### Article 8: Effective Context Engineering for AI Agents

- **ID**: context-engineering
- **File**: corpus/context-engineering.txt
- **Source**: anthropic.com/engineering/effective-context-engineering-for-ai-agents
- **Author**: Anthropic (Prithvi Rajasekaran, Ethan Dixon, Carly Ryan, Jeremy Hadfield)
- **Words**: ~2,976
- **Density**: dense (framework-heavy with specific technical concepts, named features, and concrete examples)
- **Why included**: Dense framework article defining context engineering with specific architectural concepts. Tests preservation of technical definitions, named products/features, and hedged claims.

**Core ideas (10):**

1. Context engineering is defined as curating the optimal set of tokens during LLM inference, distinct from prompt engineering which focuses on writing instructions; it emerged as agents moved from one-shot tasks to multi-turn loops. [Must distinguish context engineering from prompt engineering as broader than just prompts]
2. Context rot causes model recall accuracy to degrade as token count increases, rooted in the transformer's n-squared pairwise attention across all tokens, creating an "attention budget" with diminishing returns. [Must mention n-squared pairwise relationships and the term "attention budget"]
3. System prompts have a "Goldilocks zone" between two failure modes: overly rigid hardcoded logic that creates brittleness, and vague high-level guidance that lacks concrete signals. [Must name both failure extremes, not just recommend "balance"]
4. Claude Code uses a hybrid retrieval strategy: CLAUDE.md files are loaded upfront into context naively, while glob and grep provide just-in-time navigation, bypassing stale indexing and complex syntax trees. [Must mention CLAUDE.md loaded upfront and glob/grep for just-in-time retrieval as the two halves of the hybrid]
5. Compaction summarizes a conversation nearing the context limit and reinitiates a new window with the summary; in Claude Code, the five most recently accessed files are preserved alongside the compressed context. [Must mention the specific detail of five most recent files]
6. Tool result clearing, removing raw results of old tool calls deep in message history, is described as one of the safest and lightest forms of compaction, recently launched as a feature on the Claude Developer Platform. [Must identify tool result clearing as a specific compaction technique and its platform launch]
7. Claude playing Pokemon demonstrates structured note-taking by maintaining precise tallies across thousands of game steps, such as tracking "for the last 1,234 steps I've been training my Pokemon in Route 1, Pikachu has gained 8 levels toward the target of 10." [Must include the Pokemon example with the specific 1,234 steps / 8 levels detail]
8. Sub-agent architectures have specialized sub-agents explore extensively using tens of thousands of tokens but return condensed summaries of only 1,000-2,000 tokens, achieving separation of concerns between deep technical work and high-level synthesis. [Must mention the 1,000-2,000 token return size]
9. A memory tool was released in public beta alongside the Sonnet 4.5 launch on the Claude Developer Platform, providing file-based persistent storage outside the context window. [Must tie the memory tool to the Sonnet 4.5 launch specifically]
10. The guiding principle across all techniques is finding the smallest set of high-signal tokens that maximize the likelihood of the desired outcome, treating context as a precious finite resource even as model capabilities scale. [Must state the "smallest set of high-signal tokens" formulation as the unifying principle]

### Article 9: Patterns for Building LLM-based Systems & Products

- **ID**: llm-patterns
- **File**: corpus/llm-patterns.txt
- **Source**: eugeneyan.com/writing/llm-patterns/
- **Author**: Eugene Yan
- **Words**: ~6,449
- **Density**: dense (comprehensive catalog with specific benchmarks, named papers, and concrete examples across 7 patterns)
- **Why included**: Longest and densest article in corpus. Catalog structure with 7 patterns, numerous named papers/tools, and specific numerical claims. Tests compression of dense reference material with many specific details.

**Core ideas (10):**

1. Dense Passage Retrieval (DPR) showed dense embeddings outperform BM25 for document retrieval with 65.2% vs 42.9% top-5 accuracy on open-domain QA. [Must mention DPR and both numbers: 65.2% and 42.9%]
2. G-Eval found GPT-4 as evaluator achieved a Spearman correlation of 0.514 with human judgments, outperforming traditional metrics on coherence, consistency, fluency, and relevance. [Must mention G-Eval, GPT-4, and the 0.514 correlation figure]
3. InstructGPT used 13k instruction-output samples for supervised fine-tuning, 33k output comparisons for reward modeling, and 31k prompts for RLHF. [Must mention InstructGPT and at least two of the three specific sample counts]
4. QLoRA reduced memory requirements for fine-tuning a 65B parameter model from over 780GB to 48GB using 4-bit quantization without degrading performance. [Must mention QLoRA, the 780GB-to-48GB reduction, and 4-bit quantization]
5. LLMs exhibit self-enhancement bias when used as evaluators: GPT-4 favors its own output by 10% and Claude-v1 by 25%, so the evaluating LLM should differ from the one being evaluated. [Must mention both the GPT-4 10% and Claude-v1 25% figures]
6. Prefix tuning achieved performance comparable to full fine-tuning while updating only 0.1% of parameters, and outperformed full fine-tuning in limited-data and new-topic extrapolation settings. [Must mention 0.1% of parameters and the limited-data outperformance]
7. Microsoft's Guidelines for Human-AI Interaction started from 168 potential guidelines and narrowed them to 18, organized by user journey phases: initially, during interaction, when wrong, and over time. [Must mention the 168-to-18 narrowing and the four journey phases]
8. The Guardrails package uses Pydantic-style validation on LLM outputs with four validator categories: single value validation, syntactic checks, semantic checks, and safety checks, triggering corrective actions like output filtering or regeneration on failure. [Must mention Pydantic-style validation and the four validator categories]
9. Semantic caching of LLM responses risks serving wrong answers for similar but distinct inputs, such as returning a "Mission Impossible 2" summary for a "Mission Impossible 3" request, making item-ID-based or constrained-input caching safer alternatives. [Must mention the Mission Impossible example and at least one safer alternative like item IDs]
10. An A/B test of LLM-based customer support showed 12x greater losses compared to a human support team, leading to discontinuation after just two weeks in production. [Must mention the 12x losses figure and the two-week timeframe]

### Adding articles to the corpus

To add an article:
1. Fetch the full article text and save to `corpus/<article-id>.txt`
2. Add an entry to this file following the format above
3. Define 8-15 core ideas with testable specificity (each idea must have at least one detail that distinguishes "captured" from "vaguely paraphrased")
4. Add the article's column to the results.tsv header
5. Re-run baseline (experiment #0) to establish scores for all articles including the new one
