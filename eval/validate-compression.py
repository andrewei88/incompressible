#!/usr/bin/env python3
"""Deterministic post-compression validator and corrector.

Checks compressed output against original article for common hallucination
patterns that LLM-based evaluation misses or catches inconsistently.

Zero LLM cost. Zero variance. Runs in milliseconds.

Usage:
    python3 validate-compression.py <original.txt> <compressed.md>
    python3 validate-compression.py --fix <original.txt> <compressed.md>

In --fix mode, strips lines containing hallucinated tokens and overwrites
the compressed file. Reports what was removed. HEDGE_DROP cannot be fixed
automatically (requires re-inserting deleted words) and is only reported.

Returns exit code 0 if clean, 1 if warnings found.
Outputs warnings to stdout (parseable by compress.sh).
"""

import json
import re
import sys
from collections import Counter


def extract_years(text):
    """Extract 4-digit years (1800-2099) from text."""
    return set(re.findall(r'\b(1[89]\d{2}|20\d{2})\b', text))


def extract_numbers(text):
    """Extract significant numbers (with optional % or $ or commas).

    Decimal period is only captured if followed by at least one digit, so
    sentence-ending periods after a number are not absorbed into the token.
    """
    # Normalize "X percent" → "X%" before scanning so source and compression
    # speak the same notation. Authors write "13 percent"; compressors emit "13%".
    normalized_text = re.sub(
        r'(\d+(?:\.\d+)?)\s+percent\b',
        r'\1%',
        text,
        flags=re.IGNORECASE,
    )
    # Match numbers like 390, 1,000, $390, 40%, 10.5 — but NOT trailing punctuation
    nums = re.findall(r'[\$]?[\d,]+(?:\.\d+)?[%]?', normalized_text)
    # Normalize: strip $ and commas, keep %
    normalized = set()
    for n in nums:
        clean = n.replace(',', '').replace('$', '').strip()
        if clean and len(clean) >= 2:  # skip single digits
            normalized.add(clean)
    return normalized


def extract_hedging_context(text):
    """Find hedging words and their surrounding context (10 words each side).

    Returns list of (hedging_word, context_snippet) tuples.
    """
    hedging_patterns = [
        r'\bnecessarily\b',
        r'\bmight\b',
        r'\bcould\b',
        r'\bperhaps\b',
        r'\bprobably\b',
        r'\blikely\b',
        r'\bseems?\b',
        r'\bappears?\b',
        r'\bsuggest(?:s|ed)?\b',
        r'\btend(?:s|ed)?\b',
        r'\bI think\b',
        r'\bI believe\b',
        r'\bin my opinion\b',
        r'\broughly\b',
        r'\babout\b',
        r'\bapproximately\b',
    ]

    results = []
    words = text.split()
    text_lower = text.lower()

    for pattern in hedging_patterns:
        for match in re.finditer(pattern, text_lower):
            start = match.start()
            # Get word position
            prefix = text_lower[:start]
            word_pos = len(prefix.split())
            # Get context window
            ctx_start = max(0, word_pos - 8)
            ctx_end = min(len(words), word_pos + 8)
            context = ' '.join(words[ctx_start:ctx_end])
            results.append((match.group(), context))

    return results


def extract_person_names(text):
    """Extract likely person names (two+ capitalized words in sequence).

    More conservative than general proper noun detection. Targets the
    specific hallucination pattern of injecting names not in the source.
    """
    names = set()
    # Match sequences of 2+ capitalized words (likely person names).
    # Use [ \t]+ instead of \s+ so we don't span line breaks (which would
    # glue a name to a following heading like "Donald Knuth\n\nHard").
    sentence_starters = {
        'At', 'The', 'In', 'On', 'By', 'From', 'To', 'For', 'With', 'As',
        'And', 'But', 'Or', 'So', 'If', 'When', 'While', 'After', 'Before',
        'Now', 'Then', 'Here', 'There', 'This', 'That', 'These', 'Those',
        'His', 'Her', 'Their', 'Our', 'My', 'Your', 'Its', 'Some', 'Any',
        'All', 'Each', 'Every', 'Most', 'Many', 'Few', 'Several', 'Both',
        'Either', 'Neither', 'No', 'Not', 'One', 'Two', 'Three', 'Four',
        'Five', 'Six', 'Seven', 'Eight', 'Nine', 'Ten', 'A', 'An', 'It',
        'Is', 'Are', 'Was', 'Were', 'Be', 'Been', 'Being', 'Have', 'Has',
        'Had', 'Do', 'Does', 'Did', 'Will', 'Would', 'Should', 'Could',
        'May', 'Might', 'Must', 'Can', 'Shall', 'I', 'We', 'You', 'They',
        'He', 'She',
    }
    skip_phrases = {'United States', 'New York', 'Latin America', 'North America',
                    'South America', 'Wall Street', 'Silicon Valley'}
    for match in re.finditer(r'\b([A-Z][a-z]+(?:[ \t]+[A-Z][a-z]+)+)\b', text):
        name = match.group()
        if name in skip_phrases:
            continue
        # Strip leading sentence-starter words ("At Viaweb" -> "Viaweb")
        parts = name.split()
        while parts and parts[0] in sentence_starters:
            parts = parts[1:]
        if len(parts) >= 2:  # still a multi-word name
            names.add(' '.join(parts))
    return names


def check_title_distortion(original, compressed):
    """Check for title/role distortions.

    Looks for common title words in compression and checks they match original.
    """
    warnings = []
    title_words = ['CEO', 'VP', 'CTO', 'CFO', 'COO', 'chairman', 'president',
                   'director', 'manager', 'professor', 'doctor', 'Dr.']

    comp_lower = compressed.lower()
    orig_lower = original.lower()

    for title in title_words:
        title_lower = title.lower()
        if title_lower in comp_lower and title_lower not in orig_lower:
            warnings.append(f"TITLE: '{title}' appears in compression but not in original")

    return warnings


def analyze(original, compressed):
    """Run all validation checks against in-memory strings.

    Returns (warnings, offenders) where:
      warnings: list of human-readable warning strings
      offenders: dict mapping token -> case_sensitive_bool, used by fix mode
                 to know which tokens to strip from the compression
    """
    warnings = []
    offenders = {}  # token -> case_sensitive

    # 1. Year/date injection check
    orig_years = extract_years(original)
    comp_years = extract_years(compressed)
    added_years = comp_years - orig_years
    for year in sorted(added_years):
        warnings.append(f"YEAR_INJECTION: '{year}' in compression but not in original article")
        offenders[year] = True  # exact match

    # 2. Significant number check (large numbers, percentages, dollar amounts)
    orig_nums = extract_numbers(original)
    comp_nums = extract_numbers(compressed)
    added_nums = comp_nums - orig_nums
    added_nums = {n for n in added_nums
                  if (n.endswith('%') or n.startswith('$') or
                      (n.replace('.', '').isdigit() and float(n) > 100))}
    for num in sorted(added_nums):
        warnings.append(f"NUMBER_INJECTION: '{num}' in compression but not in original")
        offenders[num] = True

    # 3. Hedging presence check (cannot be auto-fixed)
    orig_hedges = extract_hedging_context(original)
    if orig_hedges:
        comp_lower = compressed.lower()
        for hedge_word, context in orig_hedges:
            if hedge_word == 'necessarily' and hedge_word not in comp_lower:
                warnings.append(f"HEDGE_DROP: 'necessarily' in original (\"{context}\") but not in compression")
                # Not added to offenders — cannot fix by stripping

    # 4. Title/role distortion check
    title_words = ['CEO', 'VP', 'CTO', 'CFO', 'COO', 'chairman', 'president',
                   'director', 'manager', 'professor', 'doctor', 'Dr.']
    comp_lower = compressed.lower()
    orig_lower = original.lower()
    for title in title_words:
        title_lower = title.lower()
        if title_lower in comp_lower and title_lower not in orig_lower:
            warnings.append(f"TITLE: '{title}' appears in compression but not in original")
            offenders[title] = False  # case-insensitive

    # 5. Person name injection check (case-insensitive against original
    # so that "Google Search" doesn't flag when original has "Google search",
    # and sentence-starter capitalizations like "Why Transmeta" / "Teaching Java"
    # don't fire when the lowercase phrase exists in the original).
    comp_body = re.sub(r'^#+\s+.*$', '', compressed, flags=re.MULTILINE)
    comp_body = re.sub(r'^\|.*$', '', comp_body, flags=re.MULTILINE)
    comp_body = re.sub(r'^\*\*.*?\*\*\s*$', '', comp_body, flags=re.MULTILINE)
    orig_lower_text = original.lower()
    orig_words_lower = set(re.findall(r'\b[a-z]+\b', orig_lower_text))
    comp_names = extract_person_names(comp_body)
    for name in sorted(comp_names):
        if name.lower() in orig_lower_text:
            continue
        # Only flag if at least one constituent word is novel.
        # If every word appears somewhere in the original (even separately),
        # this is likely a paraphrase, not a hallucinated name.
        words = [w.lower() for w in name.split()]
        novel = [w for w in words if w not in orig_words_lower]
        if not novel:
            continue
        warnings.append(f"NAME_INJECTION: '{name}' in compression but not in original")
        offenders[name] = True

    return warnings, offenders


def validate(original_path, compressed_path):
    """Read files and return warning strings (back-compat API).

    If compressed_path is JSON, flatten section content so top-level metadata
    fields like originalWordCount don't leak into the analyzed text.
    """
    with open(original_path, 'r') as f:
        original = f.read()
    with open(compressed_path, 'r') as f:
        raw = f.read()
    compressed = raw
    if compressed_path.endswith('.json'):
        try:
            compressed = _flatten_json_to_text(json.loads(raw))
        except (ValueError, AttributeError):
            compressed = raw
    warnings, _ = analyze(original, compressed)
    return warnings


def fix(original_path, compressed_path):
    """Strip lines containing hallucinated tokens. Overwrites compressed file.

    Returns (warnings_before, removed_lines, remaining_warnings).
    HEDGE_DROP cannot be fixed and is reported in remaining_warnings.
    """
    with open(original_path, 'r') as f:
        original = f.read()
    with open(compressed_path, 'r') as f:
        compressed = f.read()

    warnings, offenders = analyze(original, compressed)

    if not offenders:
        return warnings, [], warnings

    def _build_pattern(token):
        left = r'\b' if re.match(r'\w', token) else r'(?:^|(?<=\W))'
        right = r'\b' if re.search(r'\w$', token) else r'(?=\W|$)'
        return left + re.escape(token) + right

    def _text_has_offender(text):
        for token, case_sensitive in offenders.items():
            flags = 0 if case_sensitive else re.IGNORECASE
            if re.search(_build_pattern(token), text, flags):
                return True
        return False

    # Sentence splitter: period/!/? followed by whitespace and a capital letter.
    # Imperfect on abbreviations but adequate for compressed prose.
    _SENT_SPLIT = re.compile(r'(?<=[.!?])\s+(?=[A-Z"\'])')

    def _strip_sentences(text):
        """Drop sentences containing offenders. Returns (cleaned_text, dropped_count)."""
        sentences = _SENT_SPLIT.split(text)
        if len(sentences) <= 1:
            return None, 0  # nothing to split — let caller fall back to line strip
        kept_sents = [s for s in sentences if not _text_has_offender(s)]
        dropped = len(sentences) - len(kept_sents)
        if not kept_sents:
            return None, dropped  # everything offended — caller falls back
        return ' '.join(kept_sents), dropped

    # Strip any line containing an offender token
    lines = compressed.split('\n')
    kept = []
    removed = []
    in_code_block = False
    for line in lines:
        # Don't strip inside fenced code/mermaid blocks — too risky
        if line.strip().startswith('```'):
            in_code_block = not in_code_block
            kept.append(line)
            continue
        if in_code_block:
            kept.append(line)
            continue

        if not _text_has_offender(line):
            kept.append(line)
            continue

        # Try sentence-level surgery first (skip table rows — they need cell-level handling)
        is_table_row = line.lstrip().startswith('|')
        if not is_table_row:
            # Detect leading list/heading marker so we can preserve it
            m = re.match(r'^(\s*(?:[-*+]|\d+\.|#+)\s+)(.*)$', line)
            prefix, body = (m.group(1), m.group(2)) if m else ('', line)
            cleaned_body, _ = _strip_sentences(body)
            if cleaned_body is not None:
                kept.append(prefix + cleaned_body)
                continue

        removed.append(line)

    # Collapse runs of 3+ blank lines down to 2 (cleanup after stripping)
    cleaned = []
    blank_run = 0
    for line in kept:
        if line.strip() == '':
            blank_run += 1
            if blank_run <= 2:
                cleaned.append(line)
        else:
            blank_run = 0
            cleaned.append(line)

    with open(compressed_path, 'w') as f:
        f.write('\n'.join(cleaned))

    # Re-run analysis to get remaining warnings (HEDGE_DROP and any partial misses)
    with open(compressed_path, 'r') as f:
        new_compressed = f.read()
    remaining, _ = analyze(original, new_compressed)

    return warnings, removed, remaining


def _flatten_json_to_text(data):
    """Concatenate every leaf string in the compressed JSON into one blob.
    Used to feed analyze() so it can detect tokens across the whole document.
    Mirrors the schema understood by evaluate-production.sh."""
    parts = []
    for s in data.get('sections', []):
        if s.get('title'):
            parts.append(str(s['title']))
        c = s.get('content', {})
        for key in ('points', 'steps'):
            for item in c.get(key, []):
                parts.append(str(item))
        for row in c.get('rows', []):
            for cell in row:
                parts.append(str(cell))
        for event in c.get('events', []):
            for item in event.get('items', []):
                parts.append(str(item))
        for group in c.get('groups', []):
            for item in group.get('items', []):
                parts.append(str(item))
        for key in ('mermaid', 'code', 'explanation'):
            if key in c:
                parts.append(str(c[key]))
    return '\n'.join(parts)


def _has_offender(text, offenders):
    """Check if text contains any offender token (boundary-aware match)."""
    for token, case_sensitive in offenders.items():
        flags = 0 if case_sensitive else re.IGNORECASE
        left = r'\b' if re.match(r'\w', token) else r'(?:^|(?<=\W))'
        right = r'\b' if re.search(r'\w$', token) else r'(?=\W|$)'
        pattern = left + re.escape(token) + right
        if re.search(pattern, text, flags):
            return True
    return False


def fix_json(original_path, json_path):
    """Strip JSON leaf strings containing hallucinated tokens.

    Walks sections[].content and removes points/steps/rows/items that match
    a detected offender. Leaves mermaid/code/explanation alone (stripping
    inside would break syntax). Empty sections after stripping are removed.

    Returns (warnings_before, removed_descriptions, remaining_warnings).
    HEDGE_DROP cannot be fixed and is reported in remaining_warnings.
    """
    with open(original_path, 'r') as f:
        original = f.read()
    with open(json_path, 'r') as f:
        data = json.load(f)

    flat = _flatten_json_to_text(data)
    warnings, offenders = analyze(original, flat)

    if not offenders:
        return warnings, [], warnings

    removed = []

    new_sections = []
    for s in data.get('sections', []):
        c = s.get('content', {}) or {}

        # Section title — flag but don't strip (drastic)
        title = s.get('title', '')
        if title and _has_offender(title, offenders):
            removed.append(f"[NOT STRIPPED — section title] {title}")

        # points / steps — list of strings
        for key in ('points', 'steps'):
            if key in c:
                kept = []
                for item in c[key]:
                    if _has_offender(str(item), offenders):
                        snippet = str(item)[:100]
                        removed.append(f"{key}: {snippet}")
                    else:
                        kept.append(item)
                c[key] = kept

        # rows — list of cell-lists; strip whole row
        if 'rows' in c:
            kept_rows = []
            for row in c['rows']:
                row_text = ' | '.join(str(cell) for cell in row)
                if _has_offender(row_text, offenders):
                    removed.append(f"row: {row_text[:100]}")
                else:
                    kept_rows.append(row)
            c['rows'] = kept_rows

        # events[].items
        for event in c.get('events', []):
            if 'items' in event:
                kept_items = []
                for item in event['items']:
                    if _has_offender(str(item), offenders):
                        removed.append(f"event item: {str(item)[:100]}")
                    else:
                        kept_items.append(item)
                event['items'] = kept_items

        # groups[].items
        for group in c.get('groups', []):
            if 'items' in group:
                kept_items = []
                for item in group['items']:
                    if _has_offender(str(item), offenders):
                        removed.append(f"group item: {str(item)[:100]}")
                    else:
                        kept_items.append(item)
                group['items'] = kept_items

        # Drop section if all content arrays are now empty (no points,
        # steps, rows, events, groups, and no mermaid/code/explanation).
        has_content = (
            c.get('points') or c.get('steps') or c.get('rows') or
            any(e.get('items') for e in c.get('events', [])) or
            any(g.get('items') for g in c.get('groups', [])) or
            c.get('mermaid') or c.get('code') or c.get('explanation')
        )
        if has_content:
            new_sections.append(s)
        else:
            removed.append(f"[empty section dropped] {title}")

    data['sections'] = new_sections

    with open(json_path, 'w') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)

    # Re-analyze to get remaining warnings
    flat_new = _flatten_json_to_text(data)
    remaining, _ = analyze(original, flat_new)
    return warnings, removed, remaining


if __name__ == '__main__':
    args = sys.argv[1:]
    fix_mode = False
    fix_json_mode = False
    if args and args[0] == '--fix':
        fix_mode = True
        args = args[1:]
    elif args and args[0] == '--fix-json':
        fix_json_mode = True
        args = args[1:]

    if len(args) != 2:
        print(f"Usage: {sys.argv[0]} [--fix | --fix-json] <original.txt> <compressed>", file=sys.stderr)
        sys.exit(2)

    original_path, compressed_path = args

    if fix_json_mode:
        before, removed, remaining = fix_json(original_path, compressed_path)
        if not before:
            print("=== Validation: clean ===")
            sys.exit(0)
        fixable = len(before) - len(remaining)
        print(f"=== JSON Corrector: {fixable} fixed, {len(remaining)} unfixable ===")
        if removed:
            print(f"  Stripped {len(removed)} JSON leaf/leaves containing hallucinated tokens:")
            for desc in removed:
                print(f"    - {desc}")
        if remaining:
            print(f"  Remaining warnings (cannot auto-fix):")
            for w in remaining:
                print(f"    {w}")
        sys.exit(1 if remaining else 0)

    if fix_mode:
        before, removed, remaining = fix(original_path, compressed_path)
        if not before:
            print("=== Validation: clean ===")
            sys.exit(0)

        fixable = len(before) - len(remaining)
        print(f"=== Corrector: {fixable} fixed, {len(remaining)} unfixable ===")
        if removed:
            print(f"  Stripped {len(removed)} line(s) containing hallucinated tokens:")
            for line in removed:
                snippet = line.strip()[:120]
                print(f"    - {snippet}")
        if remaining:
            print(f"  Remaining warnings (cannot auto-fix):")
            for w in remaining:
                print(f"    {w}")
        sys.exit(1 if remaining else 0)

    warnings = validate(original_path, compressed_path)

    if warnings:
        print(f"=== Validation: {len(warnings)} warning(s) ===")
        for w in warnings:
            print(f"  {w}")
        sys.exit(1)
    else:
        print("=== Validation: clean ===")
        sys.exit(0)
