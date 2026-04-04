#!/bin/bash
# evaluate.sh - Evaluate a compressed article against its core ideas checklist
# Usage: bash evaluate.sh <article-id> <checklist-file> [output-dir]
#
# Returns structured output:
#   - Per-idea scores (Present/Absent) with reasons
#   - Score: X/Y
#   - Hallucination check: list of claims not in original
#   - Hallucinations: N
#   - Compression: X.X% (compressed/original word ratio)

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

## Job 2: Precision check (hallucination detection)

After the score, review the compressed article for claims NOT in the original. For each claim in the compression, ask: "Did the original article say this, or was it added?"

A hallucination is any claim in the compression that:
- States a fact not in the original (even if factually correct from external knowledge)
- Adds a framework, term, or analogy the author didn't use
- Upgrades hedged language to definitive claims ("might" → "will")
- Adds causal links the author left ambiguous
- Attributes specific numbers the author didn't state

After the recall score, write:
Hallucination check:
- [List each hallucinated claim, or "None found"]
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

# Section count (deterministic)
SECTIONS_COUNT=$(grep -c '^## ' "$COMPRESSED_PATH" 2>/dev/null || echo 0)
echo "Sections: ${SECTIONS_COUNT}"
