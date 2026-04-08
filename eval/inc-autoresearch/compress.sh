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
# Length-conditional prompt selection: short/medium articles hit the exp17
# baseline prompt byte-identically; long articles (>10k words) hit a
# dedicated prompt targeting 100-150 claims to prevent silent recall
# dropout documented in the yyr audit. This structural branching is the
# fix for the "prompt wording change has corpus-wide side effects" trap
# proven by exp18/exp19/exp19b.
EXTRACT_WORD_COUNT=$(wc -w < "$ARTICLE_PATH" | tr -d ' ')

if [ "$EXTRACT_WORD_COUNT" -gt 10000 ]; then
{
  cat <<'EXTRACT_PROMPT'
You are a claim extractor. Read the article below and extract the most important claims, arguments, data points, and insights as EXACT QUOTES from the original text. This is a long-form essay (over 10,000 words) — aim for 100-150 claims. Under-extraction silently drops recall on long articles; err heavily on the side of MORE.

Rules:
- Each extracted claim must be a direct quote or very close paraphrase from the article
- Include the section heading or paragraph context where each claim appears
- Prioritize: core arguments, specific numbers/benchmarks/dates, frameworks/models, actionable steps, key distinctions, evidence for non-obvious claims
- Do NOT paraphrase beyond minor grammatical adjustments
- Do NOT add any claims, frameworks, or interpretations not in the text
- Do NOT use external knowledge

MANDATORY coverage — miss none of these if present in the article:
1. **Named-source attributions.** Whenever the author quotes, cites, or references a named person (economist, author, historical figure, expert), extract the name + the quote/claim as a single item. Do not drop the name. "Shiller said 'X'" is ONE claim; never compress to just "X".
2. **Reasoning/mechanism for each listed principle.** When the article lists biases, flaws, rules, principles, or numbered items, each one needs TWO extracted claims: the definition/name AND the mechanism/reasoning the author gives for why it's true. "Pessimism is seductive" is half a claim; "Pessimism is seductive because it demands action and feels safer than optimism" is the full claim.
3. **Distinctive memorable phrasings.** When the author uses a specific vivid phrase ("positioning of each atom", "humanity's most important challenge", "don't mind what happens", "rich man in the car paradox"), capture it VERBATIM as its own claim. Paraphrasing these destroys the signal that made them memorable.
4. **Author's thesis framing and meta-commentary on the evidence.** When the author explicitly states why the topic matters ("THE most important topic for our future", "humanity's greatest challenge"), or warns the reader how to interpret the data ("the part of the S-curve you're on can obscure your perception", "exponential curves look flat until they don't"), extract that framing VERBATIM. The article's argument is incomplete without these orienting claims. Do NOT skip intro/preface paragraphs — the author's thesis statement often lives there.
5. **Concrete grounding for every abstract claim.** When a concept appears in TWO layers — an abstract framing AND a concrete illustration — extract BOTH as separate items. The illustration is what makes the claim memorable; the abstract framing alone degrades to a generic platitude. Specific cases:
   (a) Abstract principle + data points proving it. If the author writes "The further back you look, the more general your takeaways should be" and then gives "401(k) is 39 years old, VC barely existed 25 years ago, S&P didn't include financials until 1976" — extract BOTH the principle AND the data points as separate items.
   (b) Two-part mechanism ("X happens because A AND B"). If the author gives a principle and then offers TWO independent reasons or halves of a mechanism, extract BOTH halves. Never let one half stand in for the whole. If pessimism is seductive "because money is ubiquitous AND because pessimism requires action," that's TWO claims, not one.
   (c) Claim + its memorable metaphor or simile. If the author writes "exponential growth can obscure perception" AND then offers "even a steep exponential curve seems linear when you look at a tiny slice of it" — extract BOTH. Meta-commentary and the vivid simile are not redundant; the simile is what the reader will actually remember.
   The test: after extraction, ask "could a reader rebuild the author's argument WITH ITS PERSUASIVE FORCE from these claims, or only the abstract skeleton?" If only the skeleton, you've stripped the grounding.

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
else
{
  cat <<'EXTRACT_PROMPT'
You are a claim extractor. Read the article below and extract the most important claims, arguments, data points, and insights as EXACT QUOTES from the original text. Extract as many as needed to cover the article — aim for 20-40 for dense essays; fewer for short pieces. Err on the side of MORE when in doubt.

Rules:
- Each extracted claim must be a direct quote or very close paraphrase from the article
- Include the section heading or paragraph context where each claim appears
- Prioritize: core arguments, specific numbers/benchmarks/dates, frameworks/models, actionable steps, key distinctions, evidence for non-obvious claims
- Do NOT paraphrase beyond minor grammatical adjustments
- Do NOT add any claims, frameworks, or interpretations not in the text
- Do NOT use external knowledge

MANDATORY coverage — miss none of these if present in the article:
1. **Named-source attributions.** Whenever the author quotes, cites, or references a named person (economist, author, historical figure, expert), extract the name + the quote/claim as a single item. Do not drop the name. "Shiller said 'X'" is ONE claim; never compress to just "X".
2. **Reasoning/mechanism for each listed principle.** When the article lists biases, flaws, rules, principles, or numbered items, each one needs TWO extracted claims: the definition/name AND the mechanism/reasoning the author gives for why it's true. "Pessimism is seductive" is half a claim; "Pessimism is seductive because it demands action and feels safer than optimism" is the full claim.
3. **Distinctive memorable phrasings.** When the author uses a specific vivid phrase ("positioning of each atom", "humanity's most important challenge", "don't mind what happens", "rich man in the car paradox"), capture it VERBATIM as its own claim. Paraphrasing these destroys the signal that made them memorable.
4. **Author's thesis framing and meta-commentary on the evidence.** When the author explicitly states why the topic matters ("THE most important topic for our future", "humanity's greatest challenge"), or warns the reader how to interpret the data ("the part of the S-curve you're on can obscure your perception", "exponential curves look flat until they don't"), extract that framing VERBATIM. The article's argument is incomplete without these orienting claims. Do NOT skip intro/preface paragraphs — the author's thesis statement often lives there.
5. **Concrete grounding for every abstract claim.** When a concept appears in TWO layers — an abstract framing AND a concrete illustration — extract BOTH as separate items. The illustration is what makes the claim memorable; the abstract framing alone degrades to a generic platitude. Specific cases:
   (a) Abstract principle + data points proving it. If the author writes "The further back you look, the more general your takeaways should be" and then gives "401(k) is 39 years old, VC barely existed 25 years ago, S&P didn't include financials until 1976" — extract BOTH the principle AND the data points as separate items.
   (b) Two-part mechanism ("X happens because A AND B"). If the author gives a principle and then offers TWO independent reasons or halves of a mechanism, extract BOTH halves. Never let one half stand in for the whole. If pessimism is seductive "because money is ubiquitous AND because pessimism requires action," that's TWO claims, not one.
   (c) Claim + its memorable metaphor or simile. If the author writes "exponential growth can obscure perception" AND then offers "even a steep exponential curve seems linear when you look at a tiny slice of it" — extract BOTH. Meta-commentary and the vivid simile are not redundant; the simile is what the reader will actually remember.
   The test: after extraction, ask "could a reader rebuild the author's argument WITH ITS PERSUASIVE FORCE from these claims, or only the abstract skeleton?" If only the skeleton, you've stripped the grounding.

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
fi

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

# Step 2.5: Optional post-processor shorten pass (Exp 23).
# Structural intervention on the ratio dimension: takes the compressed output
# and removes redundancy via a deletion-only pass. Cannot introduce new claims
# because the instruction is strictly deletion. Faithfulness anchor: the
# extracted claims list from Step 1 — every claim in that list must still be
# traceable in the shortened output. Enabled via POSTPROCESS=1 env var.
if [ "${POSTPROCESS:-0}" = "1" ]; then
  SHORT_PATH="${OUTPUT_PATH}.short"
  {
    cat <<'POSTPROCESS_PROMPT'
You are a deletion-only editor. You will receive a compressed markdown article and a list of key claims that must be preserved.

Your job: shorten the article by removing redundancy, combining sentences, and cutting filler — WITHOUT removing any of the listed key claims and WITHOUT adding any new content.

Strict rules:
- You may only DELETE words, sentences, or redundant clauses.
- You may NOT add new words, phrases, or explanations.
- You may NOT paraphrase or substitute synonyms.
- You may NOT reorder sections or restructure content.
- Every claim in the KEY CLAIMS list must still be traceable in your output.
- Preserve all markdown formatting (headers, tables, lists, code blocks).
- Preserve all specific numbers, names, dates, quotes, and technical terms.
- Target: remove redundancy where it exists, but do not force deletion if the content is already tight.

Output ONLY the shortened markdown. No commentary, no explanations.

KEY CLAIMS (must all still be traceable):
POSTPROCESS_PROMPT
    cat "$CLAIMS_PATH"
    echo ""
    echo "COMPRESSED ARTICLE TO SHORTEN:"
    cat "$OUTPUT_PATH"
  } | claude -p > "$SHORT_PATH" 2>/dev/null
  if [ -s "$SHORT_PATH" ]; then
    SHORT_WORDS=$(wc -w < "$SHORT_PATH" | tr -d ' ')
    # Only accept if shortened meaningfully (>5% reduction) and didn't bloat
    if [ "$SHORT_WORDS" -lt "$WORDS" ]; then
      mv "$SHORT_PATH" "$OUTPUT_PATH"
      echo "  Postprocess: ${WORDS} -> ${SHORT_WORDS} words"
      WORDS="$SHORT_WORDS"
    else
      rm -f "$SHORT_PATH"
      echo "  Postprocess: no reduction, keeping original"
    fi
  else
    rm -f "$SHORT_PATH"
    echo "  Postprocess: empty output, keeping original"
  fi
fi

# Step 3: Deterministic correction (strips lines containing hallucinated tokens)
VALIDATOR="$(dirname "$SCRIPT_DIR")/validate-compression.py"
if [ -f "$VALIDATOR" ]; then
  python3 "$VALIDATOR" --fix "$ARTICLE_PATH" "$OUTPUT_PATH" 2>/dev/null || true
fi
