#!/bin/zsh
# evaluate-production.sh - Independent quality gate for compressed articles
# Usage: bash evaluate-production.sh <original-text-file> <compressed-json-file>
#
# Runs a process-isolated evaluator (claude -p) that has NEVER seen the
# compression process. It reads the original and compression cold.
#
# Checks:
#   1. Completeness: Are the 10-15 most important ideas captured?
#   2. Faithfulness: Does every claim trace to the original?
#   3. Actionable fixes: What to REMOVE, ADD, or FIX
#   4. Section coverage: Does each original heading have a corresponding section?
#   5. Format quality: Are the chosen formats appropriate for the content?
#
# Output format (parseable lines at end):
#   Completeness: X/Y
#   Hallucinations: N
#   Section coverage: X/Y
#   Format issues: N
#   Compression: X.X% (N/M words)
#   Verdict: PASS | WARN | FAIL

set -euo pipefail

ORIGINAL="$1"
COMPRESSED_JSON="$2"

if [ ! -f "$ORIGINAL" ]; then
  echo "ERROR: Original text not found: $ORIGINAL" >&2
  exit 1
fi

if [ ! -f "$COMPRESSED_JSON" ]; then
  echo "ERROR: Compressed JSON not found: $COMPRESSED_JSON" >&2
  exit 1
fi

# Deterministic compression ratio
ORIGINAL_WORDS=$(wc -w < "$ORIGINAL" | tr -d ' ')
COMPRESSED_WORDS=$(python3 -c "
import json, sys
data = json.load(open('$COMPRESSED_JSON'))
words = 0
for s in data.get('sections', []):
    c = s.get('content', {})
    for key in ['points', 'steps']:
        for item in c.get(key, []):
            words += len(str(item).split())
    for row in c.get('rows', []):
        for cell in row:
            words += len(str(cell).split())
    for event in c.get('events', []):
        for item in event.get('items', []):
            words += len(str(item).split())
    if 'mermaid' in c:
        words += len(c['mermaid'].split())
    if 'code' in c:
        words += len(c['code'].split())
    if 'explanation' in c:
        words += len(c['explanation'].split())
    for group in c.get('groups', []):
        for item in group.get('items', []):
            words += len(str(item).split())
print(words)
")
COMPRESSION_PCT=$(echo "scale=1; $COMPRESSED_WORDS * 100 / $ORIGINAL_WORDS" | bc)

# Run process-isolated evaluation
for attempt in 1 2 3; do
  eval_result=$({
    cat <<'EVAL_INSTRUCTIONS'
You are an independent evaluator. You have NOT seen the compression process. You are reading the original article and the compression for the first time.

## Job 1: Completeness check

Read the original article carefully. Identify the 10-15 most important ideas, claims, arguments, or data points. These are the things a reader MUST get from the compression to understand the article.

For each, check whether it appears in the compression (even if paraphrased).

Format (one per line):
1. [Present/Absent] "key idea summary" — reason
2. [Present/Absent] "key idea summary" — reason
...
Then on its own line: Completeness: X/Y

## Job 2: Faithfulness check

Read every claim in the compression. For each, ask: "Did the original article say this?"

Flag any claim that:
- States a fact not in the original (even if factually correct from external knowledge)
- Adds a framework, term, or analogy the author didn't use
- Upgrades hedged language to definitive claims ("might" → "will")
- Reverses or distorts the original's meaning
- Derives or computes values the author didn't state
- Infers a year, date, or attribution from metadata rather than article text

Format:
Hallucination check:
- [each flagged claim and reason, or "None found"]
Then on its own line: Hallucinations: N

## Job 3: Actionable fixes

List specific changes needed. Use EXACTLY these prefixes:
- REMOVE: "exact claim text from compression" — reason
- ADD: "missing key idea" — source: "exact quote from original article"
- FIX: "current claim text" → "corrected version" — reason

If no fixes needed, write: No fixes needed.

## Job 4: Section coverage

List every major heading (h1, h2, h3) or distinct topic from the original article that contains substantive content (skip generic intro/conclusion, license, acknowledgments).

For each, check whether the compression has a corresponding section that covers that topic. The compression section title doesn't need to match exactly, just cover the same topic.

Format (one per line):
1. [Covered/Missing] "original heading or topic" — which compression section covers it, or "not represented"
...
Then on its own line: Section coverage: X/Y

## Job 5: Format appropriateness

For each section in the compression, evaluate whether the chosen format is the fastest to scan for that content. The available formats are: key-points (bullets), table, before-after, reasoning-chain, code, checklist, numbered-steps, timeline, flowchart, concept-map, mindmap, sequence-diagram, bar-chart, pie-chart, quadrant-chart, reference-table, user-journey.

Flag sections where a different format would communicate faster. Only flag clear mismatches, not borderline cases.

Format:
Format check:
- [each flagged section: "section title" uses FORMAT but would scan faster as ALT_FORMAT because REASON, or "All formats appropriate"]
Then on its own line: Format issues: N

ORIGINAL ARTICLE:
EVAL_INSTRUCTIONS
    cat "$ORIGINAL"
    echo ""
    echo "COMPRESSED OUTPUT (JSON):"
    cat "$COMPRESSED_JSON"
  } | claude -p 2>/dev/null) && break
  echo "Evaluation attempt $attempt failed, retrying..." >&2
done

# Deterministic format diversity (computed from JSON, not LLM)
FORMAT_STATS=$(python3 -c "
import json
data = json.load(open('$COMPRESSED_JSON'))
sections = data.get('sections', [])
total = len(sections)
formats = [s.get('format', 'unknown') for s in sections]
kp_count = formats.count('key-points')
unique = len(set(formats))
kp_pct = round(kp_count * 100 / total) if total > 0 else 0
print(f'{unique} unique formats, {kp_count}/{total} key-points ({kp_pct}%)')
print(f'KP_PCT={kp_pct}')
print(f'UNIQUE={unique}')
print(f'TOTAL={total}')
")
echo ""

# Output evaluation report
echo "$eval_result"
echo ""
echo "Compression: ${COMPRESSION_PCT}% (${COMPRESSED_WORDS}/${ORIGINAL_WORDS} words)"
echo "Format diversity: $(echo "$FORMAT_STATS" | head -1)"

# Parse scores and determine verdict
completeness_score=$(echo "$eval_result" | grep -o 'Completeness: [0-9]*/[0-9]*' | head -1 | sed 's/Completeness: //')
hallucination_count=$(echo "$eval_result" | grep -o 'Hallucinations: [0-9]*' | head -1 | sed 's/Hallucinations: //')
section_coverage=$(echo "$eval_result" | grep -o 'Section coverage: [0-9]*/[0-9]*' | head -1 | sed 's/Section coverage: //')
format_issues=$(echo "$eval_result" | grep -o 'Format issues: [0-9]*' | head -1 | sed 's/Format issues: //')

if [ -z "$completeness_score" ]; then
  echo "Verdict: FAIL (could not parse completeness score)"
  exit 1
fi

numerator=$(echo "$completeness_score" | cut -d/ -f1)
denominator=$(echo "$completeness_score" | cut -d/ -f2)
hallucinations=${hallucination_count:-0}
fmt_issues=${format_issues:-0}
kp_pct=$(echo "$FORMAT_STATS" | grep 'KP_PCT=' | sed 's/KP_PCT=//')

# Section coverage parsing (optional, doesn't block verdict)
if [ -n "$section_coverage" ]; then
  sc_num=$(echo "$section_coverage" | cut -d/ -f1)
  sc_den=$(echo "$section_coverage" | cut -d/ -f2)
  sc_pct=$(echo "scale=0; $sc_num * 100 / $sc_den" | bc)
else
  sc_pct=100
  section_coverage="N/A"
fi

# Verdict logic (expanded)
warnings=""

if [ "$hallucinations" -gt 2 ]; then
  echo "Verdict: FAIL (${hallucinations} hallucinations)"
  exit 0
fi

comp_pct=$(echo "scale=0; $numerator * 100 / $denominator" | bc)
if [ "$comp_pct" -lt 60 ]; then
  echo "Verdict: FAIL (completeness ${completeness_score})"
  exit 0
fi

# Collect warnings
[ "$hallucinations" -gt 0 ] && warnings="${warnings}${hallucinations} hallucinations; "
[ "$comp_pct" -lt 80 ] && warnings="${warnings}low completeness ${completeness_score}; "
[ "$sc_pct" -lt 70 ] && warnings="${warnings}low section coverage ${section_coverage}; "
[ "$kp_pct" -gt 50 ] && warnings="${warnings}${kp_pct}% key-points (>50%); "
[ "$fmt_issues" -gt 2 ] && warnings="${warnings}${fmt_issues} format issues; "

if [ -n "$warnings" ]; then
  echo "Verdict: WARN (${warnings%%; })"
else
  echo "Verdict: PASS (completeness ${completeness_score}, 0 hallucinations, section coverage ${section_coverage}, format diversity $(echo "$FORMAT_STATS" | head -1))"
fi
