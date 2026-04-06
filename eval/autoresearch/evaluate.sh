#!/bin/bash
# evaluate.sh - Evaluate a compressed article against its core ideas checklist
# Usage: bash evaluate.sh <article-id> <checklist-file> [output-dir]
# Example: bash evaluate.sh autoresearch checklists/autoresearch.txt
#
# Returns structured output:
#   - Per-idea scores (Present/Absent) with reasons
#   - Score: X/Y
#   - Hallucination check: list of claims not in original
#   - Hallucinations: N
#   - Compression: X.X% (compressed/original word ratio)
#
# The compression ratio is calculated deterministically (not by the LLM).
# Hallucination count > 0 or compression ratio outside 5-40% triggers auto-revert
# in run_experiment.sh.

set -euo pipefail

ARTICLE_ID="$1"
CHECKLIST_PATH="$2"
OUTPUT_DIR="${3:-output}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

ORIGINAL_PATH="$SCRIPT_DIR/corpus/${ARTICLE_ID}.txt"
COMPRESSED_PATH="$SCRIPT_DIR/${OUTPUT_DIR}/${ARTICLE_ID}.md"

if [ ! -f "$ORIGINAL_PATH" ]; then
  echo "ERROR: Original article not found: $ORIGINAL_PATH" >&2
  exit 1
fi

if [ ! -f "$COMPRESSED_PATH" ]; then
  echo "ERROR: Compressed article not found: $COMPRESSED_PATH" >&2
  exit 1
fi

if [ ! -f "$CHECKLIST_PATH" ]; then
  echo "ERROR: Checklist not found: $CHECKLIST_PATH" >&2
  exit 1
fi

# Calculate compression ratio deterministically
ORIGINAL_WORDS=$(wc -w < "$ORIGINAL_PATH" | tr -d ' ')
COMPRESSED_WORDS=$(wc -w < "$COMPRESSED_PATH" | tr -d ' ')
COMPRESSION_PCT=$(echo "scale=1; $COMPRESSED_WORDS * 100 / $ORIGINAL_WORDS" | bc)

# Run LLM evaluation: recall (checklist) + precision (hallucination check)
{
  cat <<'INSTRUCTIONS'
You are an independent evaluator. You have two jobs:

## Job 1: Recall check (core ideas)

Compare the compressed article against the original. Score how many core ideas were faithfully captured.

Rules:
- Score each core idea as Present (1) or Absent (0)
- "Present" means the specific detail survives, even if paraphrased
- "Absent" means missing, distorted, reversed, or reduced to vagueness
- Be strict: borderline cases score as Absent
- Do NOT use external knowledge to fill gaps

For each core idea, respond with ONLY:
1. [Present/Absent] - [brief reason]
2. [Present/Absent] - [brief reason]
...
Then on its own line: Score: X/Y

## Job 2: Precision check (atomic fact decomposition)

For each claim in the compression, decompose it into atomic facts before checking. A single sentence like "Company X, founded in 2019 in San Francisco, grew revenue 40%" contains three atomic facts: (1) founded in 2019, (2) in San Francisco, (3) grew revenue 40%.

For each atomic fact, find the specific sentence in the original that supports it. Flag any atomic fact that:
- States something not in the original (even if factually correct from external knowledge)
- Adds a framework, term, or analogy the author didn't use
- Upgrades hedged language to definitive claims ("might" → "will")
- Adds causal links the author left ambiguous
- Attributes specific numbers the author didn't state
- Reverses or distorts the original's meaning

Format your work:
Claim: "[full sentence from compression]"
  Atoms: [fact 1] ← supported by: "[source sentence]" | [fact 2] ← NOT FOUND
(You may abbreviate for claims where all atoms check out. Show full trace only for flagged claims.)

After the analysis, write:
Hallucination check:
- [List each hallucinated atomic fact with the claim it came from, or "None found"]
Hallucinations: N

ORIGINAL ARTICLE:
INSTRUCTIONS
  cat "$ORIGINAL_PATH"
  echo ""
  echo "COMPRESSED ARTICLE:"
  cat "$COMPRESSED_PATH"
  echo ""
  echo "CORE IDEAS CHECKLIST:"
  cat "$CHECKLIST_PATH"
} | claude -p

# Print compression ratio (deterministic, outside LLM evaluation)
echo "Compression: ${COMPRESSION_PCT}% (${COMPRESSED_WORDS}/${ORIGINAL_WORDS} words)"

# Format diversity (deterministic — count from compressed markdown)
# The compressed .md files use section headers and format annotations
# For JSON-based compressions, we'd parse the JSON; for markdown, we count distinct format markers
# This is a signal for the orchestrating agent, not an auto-revert trigger
SECTIONS_COUNT=$(grep -c '^## ' "$COMPRESSED_PATH" 2>/dev/null || echo 0)
echo "Sections: ${SECTIONS_COUNT}"
