# Autoresearch: General Article Compression Optimization

You are an autonomous research agent optimizing a compression skill for general (non-AI) articles. You modify `inc-skill.md`, run external compression and evaluation scripts, and keep or revert changes. You run indefinitely without pausing for human input.

## Setup (one-time, before the loop)

1. **Branch**: Create `autoresearch/inc-<date>` from current branch (e.g., `autoresearch/inc-apr04`). All work happens on this branch.
2. **Review files**: Read all three files in this directory:
   - `program.md` (this file, your instructions, DO NOT MODIFY)
   - `prepare.md` (corpus, answer keys, eval protocol, DO NOT MODIFY)
   - `inc-skill.md` (the compression skill, THIS IS THE ONLY FILE YOU EDIT)
3. **Verify corpus**: Confirm that every article in `prepare.md`'s corpus has its text cached in `corpus/<article-id>.txt`. If any are missing, fetch them and save. You cannot run experiments on articles without cached text.
4. **Verify scripts**: Confirm that `compress.sh`, `evaluate.sh`, and `run_experiment.sh` exist and are executable. Run `chmod +x *.sh` if needed.
5. **Initialize results**: If `results.tsv` doesn't exist or is empty, create it with the header row defined in prepare.md.
6. **Establish frozen baselines**: Run:
   ```bash
   bash run_experiment.sh baselines
   ```
   This compresses every corpus article using the current `inc-skill.md` and evaluates each against its checklist. The compressed outputs are saved to `baselines/` and are NOT re-compressed when inc-skill.md changes.
7. **Record baseline**: Parse the scores from the script output. Append as experiment #0 in results.tsv with verdict `BASELINE`.
8. **Confirm**: State the baseline scores and announce you're starting the loop.

## How the Scripts Work

Three shell scripts form the experiment infrastructure. Each runs `claude -p` (non-interactive pipe mode), creating a fresh Claude context with no access to your state, reasoning, or previous experiments.

- **`compress.sh <article-id> [output-dir]`**: Pipes inc-skill.md + article text into `claude -p`. Saves compressed output to `<output-dir>/<article-id>.md`. Default output-dir is `output/`.
- **`evaluate.sh <article-id> <checklist-file> [output-dir]`**: Pipes original article + compressed output + core ideas checklist into `claude -p`. Returns structured output:
  - Per-idea Present/Absent scores with reasons
  - `Score: X/Y` (recall)
  - `Hallucinations: N` (precision — claims in output not traceable to original)
  - `Compression: X.X%` (compressed/original word ratio, calculated deterministically)
- **`run_experiment.sh [output-dir]`**: Compresses all articles, then evaluates all. Prints per-article scores, hallucination counts, compression ratios, a final average, and any constraint violations. One command = one full experiment.

## The Loop

Once the loop begins, do NOT pause to ask the human if you should continue. Run autonomously until a stopping condition is met.

For each experiment:

### Step 1: Diagnose

Read the current results.tsv. Look at the most recent scores. For each corpus article, identify which core ideas from the checklists in `checklists/` are NOT captured. Look for patterns:

- Is the same TYPE of idea missed across multiple articles? (e.g., specific numbers, hedged claims, sequential dependencies)
- Is one article consistently worse than others? Why?
- What rule in inc-skill.md, if it existed, would have caught the missed ideas?

To see which ideas were missed, you can re-run evaluation on individual articles:
```bash
bash evaluate.sh <article-id> checklists/<article-id>.txt
```

### Step 2: Propose ONE mutation

Change exactly one thing in `inc-skill.md`. Types of productive mutations:

- **Classification rules**: Add a new content type, refine disambiguation between types
- **Format selection**: Change which format renders a content type
- **Compression intensity**: Adjust targets for specific article densities
- **Preservation rules**: Add rules about what to preserve (specific numbers, hedged language, named entities)
- **Post-processing**: Add scans or checks that catch missed ideas
- **Removal rules**: Delete a rule that's causing problems (sometimes less is more)

Write a clear commit message describing what you changed and why.

### Step 3: Commit

```bash
git add eval/inc-autoresearch/inc-skill.md
git commit -m "<description of the mutation>"
```

### Step 4: Run the experiment

```bash
bash run_experiment.sh
```

### Step 5: Compare

Calculate average accuracy across all corpus articles. Compare to the **frozen baseline** scores (experiment #0), not the previous experiment.

**KEEP** if ALL of these are true:
- Average accuracy improved by >= 2 points over the frozen baseline
- No single article lost more than 2 core ideas compared to its frozen baseline score
- Total corpus hallucinations did not increase by >= 2 compared to the frozen baseline's total
- No article's compression ratio is outside 5-40%

**REVERT** if ANY of these are true:
- Average accuracy did not improve by >= 2 points
- Any single article regressed by more than 2 core ideas from its frozen baseline
- Total corpus hallucinations increased by >= 2 vs baseline total
- Any article's compression ratio is outside 5-40%

If reverting:
```bash
git revert HEAD --no-edit
```

### Step 6: Record

Append a row to results.tsv with the format defined in prepare.md.

### Step 7: Loop

Return to Step 1.

## Stopping conditions

Stop the loop when ANY of these are true:

1. **Plateau**: 3 consecutive REVERT results.
2. **Perfect score**: Average accuracy reaches 100% across all corpus articles.
3. **Human interruption**: The user stops the session.

When stopping, summarize: total experiments run, total kept, final average accuracy, the mutations that were kept, and suggestions for next steps.

## Rules for you

- ONLY modify `inc-skill.md`. Never modify `program.md`, `prepare.md`, or any script.
- One mutation per experiment. Never batch multiple changes.
- Always commit before running the experiment. The git history IS the experiment log.
- If a mutation doesn't work, revert and try a DIFFERENT mutation. Don't retry the same change.
- Use the scripts for compression and evaluation. Do NOT compress or evaluate articles yourself. The scripts run in isolated `claude -p` processes.
- Parse the "Score: X/Y", "Hallucinations: N", and "Compression: X.X%" lines from script output.
- Compare against frozen baselines, not previous experiment scores, to prevent drift.
