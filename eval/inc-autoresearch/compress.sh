#!/bin/bash
# compress.sh - Compress a single article using inc-skill.md rules
# Usage: bash compress.sh <article-id> [output-dir]
#
# This is our equivalent of `uv run train.py`. The orchestrating agent
# calls this script; the compression happens in a separate Claude process.

set -euo pipefail

ARTICLE_ID="$1"
OUTPUT_DIR="${2:-output}"
MODE="${3:-abstractive}"  # abstractive, extractive, or hybrid
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

SKILL_PATH="$SCRIPT_DIR/inc-skill.md"
ARTICLE_PATH="$SCRIPT_DIR/corpus/${ARTICLE_ID}.txt"
OUTPUT_PATH="$SCRIPT_DIR/${OUTPUT_DIR}/${ARTICLE_ID}.md"

if [ ! -f "$SKILL_PATH" ]; then
  echo "ERROR: Skill file not found: $SKILL_PATH" >&2
  exit 1
fi

if [ ! -f "$ARTICLE_PATH" ]; then
  echo "ERROR: Article not found: $ARTICLE_PATH" >&2
  exit 1
fi

mkdir -p "$SCRIPT_DIR/${OUTPUT_DIR}"

CLAIMS_PATH="$SCRIPT_DIR/${OUTPUT_DIR}/${ARTICLE_ID}.claims"

# Step 1: Extract key claims as direct quotes (selection task, not generation)
{
  cat <<'EXTRACT_PROMPT'
You are a claim extractor. Read the article below and extract the 15-25 most important claims, arguments, data points, and insights as EXACT QUOTES from the original text.

Rules:
- Each extracted claim must be a direct quote or very close paraphrase from the article
- Include the section heading or paragraph context where each claim appears
- Prioritize: core arguments, specific numbers/benchmarks/dates, frameworks/models, actionable steps, key distinctions, evidence for non-obvious claims
- Do NOT paraphrase beyond minor grammatical adjustments
- Do NOT add any claims, frameworks, or interpretations not in the text
- Do NOT use external knowledge

Format:
[1] "exact quote" (Section: heading or context)
[2] "exact quote" (Section: heading or context)
...

Output ONLY the numbered list. No commentary, no introduction, no summary.
EXTRACT_PROMPT
  echo ""
  echo "ARTICLE:"
  cat "$ARTICLE_PATH"
} | claude -p > "$CLAIMS_PATH" 2>/dev/null

echo "Extracted $(wc -l < "$CLAIMS_PATH" | tr -d ' ') claim lines for ${ARTICLE_ID}"

# Step 2: Compress using extracted claims as faithfulness constraint
# Determine effective mode (hybrid checks word count)
EFFECTIVE_MODE="$MODE"
if [ "$MODE" = "hybrid" ]; then
  WORD_COUNT=$(wc -w < "$ARTICLE_PATH" | tr -d ' ')
  if [ "$WORD_COUNT" -gt 5000 ]; then
    EFFECTIVE_MODE="abstractive"
    echo "  Hybrid: ${WORD_COUNT} words > 5000, using abstractive"
  else
    EFFECTIVE_MODE="extractive"
    echo "  Hybrid: ${WORD_COUNT} words <= 5000, using extractive"
  fi
fi

if [ "$EFFECTIVE_MODE" = "extractive" ]; then
  {
    cat <<'INSTRUCTIONS'
You are an extractive compressor. Your ONLY operations are SELECTION and DELETION from the original text. You do not generate new content.

Process:
1. Read the article below.
2. Select the sentences and phrases that capture the core ideas. Use the extracted key claims as a guide for what to keep.
3. Organize selected text under section headings using markdown formatting (headers, bold, tables, lists).
4. You may shorten sentences by removing clauses, but NEVER add words or phrases not in the original article.

Strict rules:
- Every word in your output must come from the original article text. No exceptions.
- Do NOT paraphrase. Copy the author's exact words, or delete words to shorten. Never substitute synonyms.
- Do NOT add dates, names, titles, labels, or metadata not in the article text.
- Do NOT add commentary, analysis, or interpretation.
- Table headers and cell values must use only words/phrases from the original.
- If the original doesn't provide a value for a table cell, leave it empty or omit the row.
- Section headings should use phrases from the article where possible.
- Output ONLY the organized selection in markdown format. No explanations.

EXTRACTED KEY CLAIMS (use as selection guide):
INSTRUCTIONS
    cat "$CLAIMS_PATH"
    echo ""
    echo "FORMATTING RULES:"
    cat "$SKILL_PATH"
    echo ""
    echo "ARTICLE TO COMPRESS (select from this text only):"
    cat "$ARTICLE_PATH"
  } | claude -p > "$OUTPUT_PATH" 2>/dev/null
else
  {
    cat <<'INSTRUCTIONS'
You are a compression engine. Follow the skill rules below EXACTLY to compress the article that follows.

Rules:
- Every claim in your output must trace to a specific sentence in the original article.
- No external knowledge. No inferring. No gap-filling.
- Output ONLY the compressed text in markdown format. No commentary, no explanations, no metadata about what you did.

FAITHFULNESS CONSTRAINT: An independent process has extracted key claims from the article as direct quotes (listed below). Your compression must cover these claims. Do not include any claim that cannot be traced to the extracted quotes or the original article text.

EXTRACTED KEY CLAIMS:
INSTRUCTIONS
    cat "$CLAIMS_PATH"
    echo ""
    echo "SKILL RULES:"
    cat "$SKILL_PATH"
    echo ""
    echo "ARTICLE TO COMPRESS:"
    cat "$ARTICLE_PATH"
  } | claude -p > "$OUTPUT_PATH" 2>/dev/null
fi

WORDS=$(wc -w < "$OUTPUT_PATH" | tr -d ' ')
echo "Compressed ${ARTICLE_ID}: ${WORDS} words -> ${OUTPUT_PATH}"

# Step 3: Deterministic correction (strips lines containing hallucinated tokens)
VALIDATOR="$(dirname "$SCRIPT_DIR")/validate-compression.py"
if [ -f "$VALIDATOR" ]; then
  python3 "$VALIDATOR" --fix "$ARTICLE_PATH" "$OUTPUT_PATH" 2>/dev/null || true
fi
