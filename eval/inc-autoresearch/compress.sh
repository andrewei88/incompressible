#!/bin/bash
# compress.sh - Compress a single article using inc-skill.md rules
# Usage: bash compress.sh <article-id> [output-dir]
#
# This is our equivalent of `uv run train.py`. The orchestrating agent
# calls this script; the compression happens in a separate Claude process.

set -euo pipefail

ARTICLE_ID="$1"
OUTPUT_DIR="${2:-output}"
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

{
  cat <<'INSTRUCTIONS'
You are a compression engine. Follow the skill rules below EXACTLY to compress the article that follows.

Rules:
- Every claim in your output must trace to a specific sentence in the original article.
- No external knowledge. No inferring. No gap-filling.
- Output ONLY the compressed text in markdown format. No commentary, no explanations, no metadata about what you did.

SKILL RULES:
INSTRUCTIONS
  cat "$SKILL_PATH"
  echo ""
  echo "ARTICLE TO COMPRESS:"
  cat "$ARTICLE_PATH"
} | claude -p > "$OUTPUT_PATH"

WORDS=$(wc -w < "$OUTPUT_PATH" | tr -d ' ')
echo "Compressed ${ARTICLE_ID}: ${WORDS} words -> ${OUTPUT_PATH}"
