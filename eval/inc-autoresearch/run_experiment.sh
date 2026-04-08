#!/bin/bash
# run_experiment.sh - Compress and evaluate all corpus articles
# Usage: bash run_experiment.sh [output-dir]
# Example: bash run_experiment.sh          # outputs to output/
# Example: bash run_experiment.sh baselines # outputs to baselines/

set -euo pipefail

OUTPUT_DIR="${1:-output}"
MODE="${2:-abstractive}"  # abstractive, extractive, or hybrid
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

ARTICLES=("do-things-that-dont-scale" "psychology-of-money" "ai-revolution" "what-makes-you-you" "never-rewrite" "most-important-century" "seven-strange-questions" "what-you-cant-say" "back-to-basics" "you-and-your-research" "stress-academic" "stress-narrative" "stress-news")
TOTAL_SCORE=0
TOTAL_IDEAS=0
TOTAL_HALLUCINATIONS=0
CONSTRAINT_VIOLATIONS=""

COMPRESS_N="${COMPRESS_N:-1}"
echo "=== Compressing all articles (output: ${OUTPUT_DIR}/, mode: ${MODE}, N=${COMPRESS_N}) ==="
for article in "${ARTICLES[@]}"; do
  if [ "$COMPRESS_N" = "1" ]; then
    bash "$SCRIPT_DIR/compress.sh" "$article" "$OUTPUT_DIR" "$MODE"
  else
    # Median-of-N compression: run N times to temp dirs, pick the run whose
    # word count is the median, copy that one to the final output path.
    # Use this when measuring high-confidence baselines or gating ratio-targeted
    # experiments, because single-run ratio has ~5pt noise (Exp 22).
    TMP_BASE="/tmp/cmp-${OUTPUT_DIR}-${article}-$$"
    for n in $(seq 1 "$COMPRESS_N"); do
      bash "$SCRIPT_DIR/compress.sh" "$article" "${TMP_BASE}-$n" "$MODE" > /dev/null
    done
    # Pick median by word count
    MEDIAN_N=$(python3 -c "
import os, sys
counts = []
for n in range(1, $COMPRESS_N + 1):
    p = f'$SCRIPT_DIR/${TMP_BASE}-{n}/${article}.md'.replace('/tmp/', '/tmp/')
    # TMP_BASE is already absolute under /tmp
    p = f'${TMP_BASE}-{n}/${article}.md'
    try:
        with open(p) as f:
            counts.append((len(f.read().split()), n))
    except FileNotFoundError:
        pass
counts.sort()
print(counts[len(counts)//2][1] if counts else 1)
")
    mkdir -p "$SCRIPT_DIR/${OUTPUT_DIR}"
    cp "${TMP_BASE}-${MEDIAN_N}/${article}.md" "$SCRIPT_DIR/${OUTPUT_DIR}/${article}.md"
    COUNTS=$(for n in $(seq 1 "$COMPRESS_N"); do wc -w < "${TMP_BASE}-${n}/${article}.md" 2>/dev/null | tr -d ' '; done | tr '\n' ' ')
    echo "  Median-of-${COMPRESS_N} for ${article}: runs=[${COUNTS}] picked run ${MEDIAN_N}"
    rm -rf "${TMP_BASE}-"*
  fi
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
  # Median-of-N evaluation: eval variance is ~2.8 pt on identical inputs, so
  # single-run scores are unreliable. Run N=3 in parallel and take the median
  # score / max hallucination count to give aggregate scores signal.
  EVAL_N="${EVAL_N:-3}"
  TMPDIR_ART="/tmp/eval-${OUTPUT_DIR}-${article}-$$"
  mkdir -p "$TMPDIR_ART"
  for n in $(seq 1 "$EVAL_N"); do
    bash "$SCRIPT_DIR/evaluate.sh" "$article" "$CHECKLIST" "$OUTPUT_DIR" > "$TMPDIR_ART/eval-$n.txt" 2>&1 &
  done
  wait
  # Collect per-run scores and halluc counts
  SCORES=()
  HALLUCS=()
  for n in $(seq 1 "$EVAL_N"); do
    clean=$(sed 's/\*\*//g' "$TMPDIR_ART/eval-$n.txt")
    s=$(echo "$clean" | grep -E "^Score:" | tail -1 | sed 's/Score: \([0-9]*\)\/.*/\1/')
    d=$(echo "$clean" | grep -E "^Score:" | tail -1 | sed 's/Score: [0-9]*\/\([0-9]*\).*/\1/')
    h=$(echo "$clean" | grep -E "^Hallucinations:" | tail -1 | sed 's/Hallucinations: \([0-9]*\).*/\1/')
    [ -n "$s" ] && SCORES+=("$s") && DENOMINATOR="$d"
    [ -n "$h" ] && HALLUCS+=("$h")
  done
  # Print first run's full output (for debugging / context)
  cat "$TMPDIR_ART/eval-1.txt"
  # Compute median score
  SORTED=($(printf '%s\n' "${SCORES[@]}" | sort -n))
  MID=$(( ${#SORTED[@]} / 2 ))
  NUMERATOR="${SORTED[$MID]}"
  # Max hallucination count across runs (strictest)
  HALLUC_COUNT=0
  for h in "${HALLUCS[@]}"; do [ "$h" -gt "$HALLUC_COUNT" ] && HALLUC_COUNT="$h"; done

  if [ -n "${NUMERATOR:-}" ] && [ -n "${DENOMINATOR:-}" ]; then
    TOTAL_SCORE=$((TOTAL_SCORE + NUMERATOR))
    TOTAL_IDEAS=$((TOTAL_IDEAS + DENOMINATOR))
    PCT=$(echo "scale=1; $NUMERATOR * 100 / $DENOMINATOR" | bc)
    echo "=> ${article}: median ${NUMERATOR}/${DENOMINATOR} (${PCT}%) [runs: ${SCORES[*]}]"
  else
    echo "WARNING: Could not parse score for ${article}" >&2
  fi

  if [ -n "${HALLUC_COUNT:-}" ]; then
    TOTAL_HALLUCINATIONS=$((TOTAL_HALLUCINATIONS + HALLUC_COUNT))
    if [ "$HALLUC_COUNT" -gt 0 ]; then
      CONSTRAINT_VIOLATIONS="${CONSTRAINT_VIOLATIONS}  HALLUCINATION: ${article} has ${HALLUC_COUNT} hallucinated claim(s) (max across ${EVAL_N} runs)\n"
    fi
  fi

  EVAL_CLEAN=$(sed 's/\*\*//g' "$TMPDIR_ART/eval-1.txt")
  rm -rf "$TMPDIR_ART"
  COMP_LINE=$(echo "$EVAL_CLEAN" | grep -E "^Compression:" | tail -1)
  if [ -n "$COMP_LINE" ]; then
    COMP_PCT=$(echo "$COMP_LINE" | sed 's/Compression: \([0-9.]*\)%.*/\1/')
    # Per-article baseline drift check: flag if > ±40% relative to calibrated baseline.
    # Rationale (Exp 22, 2026-04-08): measured run-to-run compression variance on
    # identical inputs is ~5pt absolute (max 5.9pt on do-things-that-dont-scale and
    # back-to-basics). On low-baseline articles (e.g. what-makes-you-you at 15%),
    # 5.9pt swing = 39% relative. A ±15% threshold was tighter than the noise floor
    # and produced false alarms. ±40% captures normal noise and still flags real
    # regressions (which are typically much larger structural shifts).
    BASELINE=$(python3 -c "import json,sys; d=json.load(open('$SCRIPT_DIR/ratios_baseline.json')); print(d.get('$article',''))" 2>/dev/null)
    if [ -n "$BASELINE" ]; then
      DRIFT=$(python3 -c "b=$BASELINE; c=$COMP_PCT; print(f'{(c-b)/b*100:.1f}')")
      DRIFT_ABS=$(python3 -c "b=$BASELINE; c=$COMP_PCT; print(f'{abs((c-b)/b*100):.1f}')")
      OUT_OF_BAND=$(python3 -c "print(1 if $DRIFT_ABS > 40 else 0)")
      if [ "$OUT_OF_BAND" -eq 1 ]; then
        CONSTRAINT_VIOLATIONS="${CONSTRAINT_VIOLATIONS}  COMPRESSION: ${article} at ${COMP_PCT}% drifted ${DRIFT}% from baseline ${BASELINE}%\n"
      fi
    else
      # No baseline (new article) — fall back to absolute floor
      TOO_LOW=$(echo "$COMP_PCT < 5" | bc)
      if [ "$TOO_LOW" -eq 1 ]; then
        CONSTRAINT_VIOLATIONS="${CONSTRAINT_VIOLATIONS}  COMPRESSION: ${article} at ${COMP_PCT}% (below 5% floor, no baseline)\n"
      fi
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
