#!/bin/bash
# run_experiment.sh - Compress and evaluate all corpus articles
# Usage: bash run_experiment.sh [output-dir]
# Example: bash run_experiment.sh          # outputs to output/
# Example: bash run_experiment.sh baselines # outputs to baselines/
#
# This is our equivalent of `uv run train.py`. One command = one full experiment.
# Compresses all articles, evaluates each against its checklist, prints scores.
#
# Evaluation includes:
#   - Recall: core ideas captured (Score: X/Y)
#   - Precision: hallucination count (Hallucinations: N)
#   - Compression ratio: compressed/original word percentage
#   - Section count: number of sections in compressed output
#
# Constraints (enforced by the orchestrating agent, not this script):
#   - Hallucinations > 0 on any article → auto-revert
#   - Compression ratio outside 5-40% on any article → auto-revert
#   - Format/section quality: reported for agent judgment, not hard-gated

set -euo pipefail

OUTPUT_DIR="${1:-output}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

ARTICLES=("autoresearch" "karpathy-recipe" "prompt-engineering" "lora-tips" "karpathy-backprop" "llm-agents" "multi-agent-research" "context-engineering" "llm-patterns")
TOTAL_SCORE=0
TOTAL_IDEAS=0
TOTAL_HALLUCINATIONS=0
CONSTRAINT_VIOLATIONS=""

echo "=== Compressing all articles (output: ${OUTPUT_DIR}/) ==="
for article in "${ARTICLES[@]}"; do
  bash "$SCRIPT_DIR/compress.sh" "$article" "$OUTPUT_DIR"
done

echo ""
echo "=== Evaluating all articles ==="
for article in "${ARTICLES[@]}"; do
  CHECKLIST="$SCRIPT_DIR/checklists/${article}.txt"
  if [ ! -f "$CHECKLIST" ]; then
    echo "WARNING: No checklist for ${article}, skipping evaluation" >&2
    continue
  fi

  echo ""
  echo "--- ${article} ---"
  EVAL_OUTPUT=$(bash "$SCRIPT_DIR/evaluate.sh" "$article" "$CHECKLIST" "$OUTPUT_DIR")
  echo "$EVAL_OUTPUT"

  # Strip markdown bold markers before parsing (LLM sometimes wraps Score/Hallucinations in **)
  EVAL_CLEAN=$(echo "$EVAL_OUTPUT" | sed 's/\*\*//g')

  # Parse "Score: X/Y" from evaluation output
  SCORE_LINE=$(echo "$EVAL_CLEAN" | grep -E "^Score:" | tail -1)
  if [ -n "$SCORE_LINE" ]; then
    NUMERATOR=$(echo "$SCORE_LINE" | sed 's/Score: \([0-9]*\)\/.*/\1/')
    DENOMINATOR=$(echo "$SCORE_LINE" | sed 's/Score: [0-9]*\/\([0-9]*\).*/\1/')
    TOTAL_SCORE=$((TOTAL_SCORE + NUMERATOR))
    TOTAL_IDEAS=$((TOTAL_IDEAS + DENOMINATOR))
    PCT=$(echo "scale=1; $NUMERATOR * 100 / $DENOMINATOR" | bc)
    echo "=> ${article}: ${NUMERATOR}/${DENOMINATOR} (${PCT}%)"
  else
    echo "WARNING: Could not parse score for ${article}" >&2
  fi

  # Parse "Hallucinations: N" from evaluation output
  HALLUC_LINE=$(echo "$EVAL_CLEAN" | grep -E "^Hallucinations:" | tail -1)
  if [ -n "$HALLUC_LINE" ]; then
    HALLUC_COUNT=$(echo "$HALLUC_LINE" | sed 's/Hallucinations: \([0-9]*\).*/\1/')
    TOTAL_HALLUCINATIONS=$((TOTAL_HALLUCINATIONS + HALLUC_COUNT))
    if [ "$HALLUC_COUNT" -gt 0 ]; then
      CONSTRAINT_VIOLATIONS="${CONSTRAINT_VIOLATIONS}  HALLUCINATION: ${article} has ${HALLUC_COUNT} hallucinated claim(s)\n"
    fi
  fi

  # Parse "Compression: X.X%" from evaluation output
  COMP_LINE=$(echo "$EVAL_CLEAN" | grep -E "^Compression:" | tail -1)
  if [ -n "$COMP_LINE" ]; then
    COMP_PCT=$(echo "$COMP_LINE" | sed 's/Compression: \([0-9.]*\)%.*/\1/')
    # Check if outside 5-40% range (using bc for float comparison)
    TOO_LOW=$(echo "$COMP_PCT < 5" | bc)
    TOO_HIGH=$(echo "$COMP_PCT > 40" | bc)
    if [ "$TOO_LOW" -eq 1 ]; then
      CONSTRAINT_VIOLATIONS="${CONSTRAINT_VIOLATIONS}  COMPRESSION: ${article} at ${COMP_PCT}% (below 5% floor)\n"
    fi
    if [ "$TOO_HIGH" -eq 1 ]; then
      CONSTRAINT_VIOLATIONS="${CONSTRAINT_VIOLATIONS}  COMPRESSION: ${article} at ${COMP_PCT}% (above 40% ceiling)\n"
    fi
  fi
done

echo ""
echo "=== Summary ==="
if [ "$TOTAL_IDEAS" -gt 0 ]; then
  AVG=$(echo "scale=1; $TOTAL_SCORE * 100 / $TOTAL_IDEAS" | bc)
  echo "Total: ${TOTAL_SCORE}/${TOTAL_IDEAS} (${AVG}%)"
else
  echo "No scores parsed."
fi

echo "Hallucinations: ${TOTAL_HALLUCINATIONS}"

if [ -n "$CONSTRAINT_VIOLATIONS" ]; then
  echo ""
  echo "=== CONSTRAINT VIOLATIONS ==="
  echo -e "$CONSTRAINT_VIOLATIONS"
fi
