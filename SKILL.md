---
name: inc
description: Summarize an article into its most incompressible form — classifying content by type and rendering each section in its optimal format (table, checklist, prose, flowchart, concept map). Use when the user wants to summarize, compress, or extract key information from an article URL or text.
---

# INCMPRSBL — Article Compressor

Compress an article to its incompressible form: the point where removing anything else would lose meaning.

## Input

The user provides a URL or raw text after `/inc`. Both work equally well:
- `/inc https://example.com/article` — fetches and compresses the article at the URL
- `/inc [pasted text]` — compresses the pasted text directly (works for any content, including paywalled or bot-blocked sites where the user copies text from their browser)

## Step 1: Fetch the article

If the input is a URL:
1. Use WebFetch to retrieve the page content
2. Extract the article body text — strip navigation, ads, sidebars, footers, and boilerplate. Focus on the main content area.
3. Note the article title and source domain

**X/Twitter URLs** (`x.com` or `twitter.com`):

Determine the content type from the URL and use the fastest extraction method:

**Single tweets** (URL pattern: `/{user}/status/{id}`):
1. Try the fxtwitter API first: `WebFetch https://api.fxtwitter.com/{username}/status/{id}`. This returns tweet text as JSON with no browser needed and is much faster than Playwright.
2. If fxtwitter fails or returns incomplete data (e.g., truncated long posts), fall back to Playwright.

**X Articles** (URL pattern: `/{user}/article/{id}`, or a tweet that embeds an article):
1. Navigate Playwright directly to the focus mode URL: `https://x.com/{user}/article/{id}`. Do not navigate to the tweet first — go straight to the article. The persistent profile at `~/.playwright-profile` keeps sessions logged in.
2. Wait for content to load, then take a snapshot using the `filename` parameter (e.g., `filename: "/tmp/inc-snapshot.md"`) to avoid large inline output. Read the saved file to extract text.
3. If the page shows "page is down" or fails to load content after 5 seconds, retry navigation once — X is intermittently flaky.

**Threads** (URL is a tweet with replies by the same author):
1. Try fxtwitter first for the root tweet. If sufficient, use it.
2. If the thread is long or fxtwitter truncates, use Playwright: navigate to the tweet URL, scroll through the conversation to capture all tweets by the original author. Use the `filename` parameter for the snapshot.

**Login wall**: If Playwright shows a login wall, tell the user: "Please log into X in the Playwright browser window. Your session will persist for future use."

**Username mismatch / wrong handle**: X URLs break when the username in the URL doesn't match the current account owner. This happens when users change handles, or when a link is shared with an old username. If a tweet/article URL returns "page doesn't exist" or "this account doesn't exist":
1. Extract the status/article ID from the URL (the numeric part after `/status/` or `/article/`).
2. Try fxtwitter with just the ID: `WebFetch https://api.fxtwitter.com/i/status/{id}` (the `i` placeholder works for ID-only lookups on some mirrors).
3. If that fails, try Playwright: navigate to `https://x.com/i/status/{id}` — X sometimes resolves the correct user from the ID alone.
4. If both fail, tell the user: "This URL returned 'page not found' — the username may have changed. Can you verify the URL or paste the article text directly?"

**Non-authenticated users**: Users without an X/Twitter account cannot use Playwright-based fetching (login wall). For these users:
1. fxtwitter API works without authentication for public tweets — try this first.
2. If fxtwitter fails and the content requires login, tell the user: "This content requires X login to access. You can either: (a) log into X in the Playwright browser (`open ~/.playwright-profile`), or (b) paste the article text directly: `/inc [paste text here]`"

**Fetch failures**: If all fetch methods fail (WebFetch returns no content, fxtwitter API errors, Playwright can't load the page after retry), stop and tell the user: "Couldn't fetch the article. You can paste the text directly: `/inc [paste text here]`". Do not attempt to compress empty or boilerplate-only content.

If the input is raw text:
1. Use the text as-is
2. Ask the user for a title if one isn't obvious from the content

## Step 2: Read settings

Read `~/Projects/incompressible/settings.json`. This file is the single source of truth for format mappings (content type → visual format) and global preference. The `formatMapping` object maps each content type to its rendering format. `globalPreference` controls bias: `auto` picks the best format per section, `visual` biases toward diagrams and maps, `text` biases toward prose and lists.

## Step 3: Classify and compress

Analyze the article and produce a JSON structure. This is the critical step.

### Classification rules

Identify distinct sections of the article. Each section has one dominant information type:

| Type | What it looks like |
|---|---|
| process | Step-by-step instructions, protocols, routines, workflows |
| argument-sequential | Reasoning chain where each point depends on the previous — A because B because C |
| argument-parallel | Independent claims, observations, or insights that stand alone |
| framework | Named components with parallel attributes (each has name + description + purpose, etc.) |
| comparison | Evaluating options against the same criteria |
| concept-causal | Ideas defined by directional or causal relationships (A causes B, A enables B). The arrow test: removing arrows loses information. |
| concept-hierarchical | Ideas organized as a hierarchy branching from a central topic. Categories and subcategories, not directional relationships. |
| decision-tree | If/then branching logic, "do X when Y, do Z when W" |
| action-items | Tasks, to-dos, things to do |
| sequence | Ordered events where order is rigid and matters |
| catalog | A list or collection of items meant as a reference (e.g., "100 mental models", "50 cognitive biases") |
| chronology | Events anchored to dates or time periods (history of X, evolution of Y) |
| interaction | Back-and-forth between entities: negotiations, API flows, conversations, cause-response chains between actors |
| quadrant | 2x2 matrix frameworks: effort/impact, risk/reward, Eisenhower matrix |
| data-breakdown | Percentages, proportions, share of a whole (budget splits, market share, survey results) |
| data-comparison | Numeric values compared across categories (benchmarks, scores, rankings with numbers) |
| transformation | Before/after, old vs new, problem vs solution — two-state comparisons |
| experience | User journeys, day-in-the-life narratives, onboarding flows, emotional arcs through a process |

**Framework vs concept rule:** If the named components only have parallel attributes (name, description, purpose) and no relationships between them, use `framework → table`. If the components interact, cause each other, compensate for each other, or fail in specific ways without each other, use a concept type. The arrow test determines which: would removing arrows from a diagram lose information? If yes, use `concept-causal → concept-map` (graph TD). If the structure is hierarchical branching without directionality (a central topic with categories and subcategories), use `concept-hierarchical → mindmap`. **Default to visual formats when the content has relationships.** Tables should be the fallback for truly flat, parallel data, not the default for any named set of things.

**Argument subdivision rule:** When you encounter reasoning, ask: does each point depend on the previous? If yes → argument-sequential. If each point stands alone → argument-parallel. Most "here's why X works" or "here's what fails" sections are parallel.

**Argument-sequential format rule:** The default format for argument-sequential is key-points (short declarative sentences). Use reasoning-chain (→ arrows) only for strict causal chains where A directly causes B. Most sequential arguments build on each other conceptually but aren't strict causation. Key-points preserves the content of each point; chain notation compresses too aggressively for anything other than direct cause-and-effect.

**Ordered content disambiguation:** Three formats handle ordered content. Pick based on what carries the meaning:
- `sequence → numbered-steps`: Order matters but time markers don't. "First do X, then Y, then Z."
- `chronology → timeline`: Dates or time periods are load-bearing. "In 2008 X happened, by 2012 Y had changed." If removing the dates loses meaning, it's a timeline.
- `experience → user-journey`: The emotional/satisfaction dimension matters. "Onboarding was easy (5/5), then hit a wall at setup (1/5)." If the article describes how something *felt* at each stage, it's a journey.

**Cycle detection rule:** If a sequence's final step feeds back into the first step (creating a loop), use `flowchart` instead of `numbered-steps`. Numbered steps imply a linear process with a terminus. Cycles are fundamentally different: the looping structure IS the insight. Look for language like "restarting the cycle," "feeds back into," "repeats," or any final step that references the first. A flowchart with an arrow from last node back to first communicates the loop visually; numbered steps hide it.

**Dated events rule:** If ordered events include specific dates or years (1929, 2008, "by March"), use `timeline` instead of `numbered-steps`. The test: would removing the dates lose information? "1929 crash → 1933 Hitler → 1941 Pearl Harbor" loses meaning without dates. "First install, then configure, then deploy" doesn't. Dates are load-bearing → timeline. Order-only → numbered-steps.

**Chart disambiguation:** Three chart types serve different data relationships:
- `data-breakdown → pie-chart`: Parts of a whole that sum to 100%. "40% went to X, 35% to Y, 25% to Z."
- `data-comparison → bar-chart`: Comparing quantities across categories that don't need to sum. "Framework A scored 85, B scored 62, C scored 90."
- `framework → table`: Numbers exist but aren't the primary content. "Framework A is fast and simple. Framework B is slow but flexible." If removing the numbers wouldn't change the reader's takeaway, use a table.

**Interaction disambiguation:** Two formats handle relationships between entities:
- `interaction → sequence-diagram`: Multiple named actors exchanging messages or actions in order. "Client sends request to Server, Server queries Database, Database returns results." The actors and their exchanges are the point.
- `concept-causal → concept-map`: Concepts relate to each other but aren't actors exchanging messages. The relationships are structural, not temporal. (Use `concept-hierarchical → mindmap` if the structure is a branching hierarchy rather than a directional graph.)

**Comparison disambiguation:** Three formats handle comparisons:
- `comparison → table`: Evaluating multiple options against the same set of criteria. Classic feature comparison.
- `quadrant → quadrant-chart`: Exactly two dimensions that create four meaningful zones. Both axes must be continuous and the quadrant labels must carry meaning (e.g., "high effort / low impact" = don't do it).
- `transformation → before-after`: Exactly two states of the same thing. Not comparing options but showing change.

**Catalog rule:** If the article is primarily a catalog or reference list (many items with brief descriptions), use `catalog` type with `reference-table` format. Preserve breadth (all items) and compress depth (shorten descriptions). Don't compress a catalog into key themes — the value IS the list.

**Visual format preference:** When a section could work as either text or visual, prefer the visual format. A flowchart communicates decision logic faster than prose. A timeline communicates chronology faster than numbered steps. The reader opened a compressed article to save time. Visual formats save more time than text.

**Short article rule:** For articles under 2000 words with a single core argument, consider whether a single section (no breakdown) is more appropriate than forced multi-section structure.

**Already-compressed rule:** If the original is under 300 words and already structured as a list, table, or numbered items, skip compression. Tell the user: "This content is already near its incompressible form" and render it directly in the appropriate format (usually catalog/reference-table) without attempting to reduce word count.

### Compression rules

**Primary metric: accuracy.** The compression must be a faithful representation of the original. Every claim, framing, and characterization in the output must trace back to something the author actually wrote. Completeness (covering all key points) and compression ratio (brevity) matter, but never at the cost of accuracy. When accuracy and completeness conflict (e.g., adding context risks misrepresenting the author's intent), choose accuracy. When accuracy and compression conflict (e.g., the author's exact phrasing is needed to avoid distortion), keep the original wording.

**Keep:**
- Core claims and arguments (the "so what")
- Frameworks, models, and mental models (reusable structures)
- Actionable steps (anything the reader should do)
- Key distinctions (X is not Y, because...)
- Data or evidence supporting non-obvious claims

**Discard:**
- Anecdotes used purely for engagement (keep the point, cut the story)
- Analogies and metaphors that restate a point already made plainly (if the literal statement is clear, the metaphor is decoration)
- Repetition (once is enough)
- Social proof and credibility markers
- Filler transitions
- SEO padding and introductions
- Personal stories used to illustrate rather than inform

**Satirical and rhetorical writing:** In satire, irony, and polemic, the specific wording often IS the argument — a line like "logging in and closing the tab is usage" cannot be paraphrased without losing its force. When compressing satirical or rhetorical content:
- Preserve lines where the exact phrasing encapsulates the argument better than any summary could (the "quotable line" test: if you'd quote it verbatim when telling someone about the piece, keep it verbatim)
- Do not classify punchlines as "engagement" — in satire, the punchline delivers the claim. Cutting it is like cutting the conclusion from a syllogism.
- Preserve concrete absurdities (e.g., a support ticket that reads "the AI summary of my email is my email" / resolution: "working as designed") — these are evidence, not decoration

**Format rules:**
- Each prose paragraph should contain ONE idea. Multiple ideas → split into separate paragraphs or switch to key-points
- Table cells should be ≤15 words. If a cell needs more, the section may be better as key-points
- Prefer chains (A → B → C) over prose when logical steps can be expressed as arrows without losing meaning
- **Table semantic coherence:** Every row in a table must be an instance of the category declared by the section title. If a table is titled "Kill Criteria," every row must be a kill criterion from the original article. If titled "Evidence," every row must be evidence. Don't repurpose unrelated content to fill rows just because it fits the column structure. A true claim in the wrong structural slot is still a misrepresentation of the original's argument.

**Style rules:**
- Use short, concise sentences. If a sentence has a comma, ask whether it should be two sentences.
- Use simple words over complex ones. "Use" not "utilize". "Help" not "facilitate". "Start" not "commence". Compression should reduce cognitive load, not increase it.

**Compression intensity:**
- Heavily padded articles (lots of stories, engagement hooks): target 5-10% of original
- Satirical/rhetorical writing (repetition-for-effect, but data-rich): target 10-20% — repetitive structure is padding, but specific numbers, quotes, and punchlines are load-bearing. Strip the repetition, keep the evidence.
- Average-density articles (typical essays, blog posts): target 8-15%
- Already-dense articles (academic, technical, list-based): target 15-25%
- Never compress below 5% unless the original is extremely padded

**Post-compression scan:** After compressing, run these three checks against the original:

1. **Buried claims:** Scan the original for strong standalone claims embedded in paragraphs about other topics. Two specific patterns to watch for:
   - **Author-emphasized text:** Bullet points, bold text, italics, block quotes, or any formatting the author used to call out a principle or rule. If the author thought it was worth emphasizing, it's probably load-bearing.
   - **Concrete data in narrative paragraphs:** Specific numbers (percentages, dollar amounts, dates, durations) buried in storytelling. Numbers are incompressible — "unemployment dropped from 25% to zero" carries more information per word than any summary of "the economy improved."
   A claim that would change what the reader does or believes should be captured even if it's parenthetical in the original.

2. **Beneficiary/stakes check:** Ask "who benefits, and what do they gain?" If the original names a specific beneficiary (a person, role, or entity) and a specific reward (money, power, promotion), that must appear in the compression. Missing the beneficiary is like summarizing a crime without naming the perpetrator. Example: a $340K bonus tied to a metric the narrator invented is the financial thesis of the piece — without it, the reader doesn't understand the incentive structure.

3. **Most-quotable line test:** Identify the 1-2 lines from the original that a reader would most likely quote when sharing it. If those lines don't appear (verbatim or near-verbatim) in the compression, add them. These lines carry disproportionate meaning-per-word — they're often more compressed than anything you'd write as a summary.

4. **Faithfulness check:** Read every claim in the compression and ask: "Did the author say this, or did I infer it?" If a phrase, analogy, framework name, or characterization does not appear in the original, remove it. Compression means selecting and condensing the author's words, not adding your own. Specific patterns to catch:
   - Adding analogies the author didn't use (e.g., calling something "a Dunning-Kruger effect" when the author never used that term)
   - Upgrading hedged language to definitive claims ("might" → "will")
   - Attributing a named framework or concept the author didn't reference
   - Inserting causal links the author left ambiguous
   - Flattening probabilistic or hedged claims when compressing into table cells. ">50% probability by 2040" is not "Prediction: 2040". Tables compress phrasing but must not compress uncertainty. If the author hedged, the compression must hedge.
   The compression must be a faithful subset of the original's claims, not a remix.

**Visual/interactive content:** For articles with significant visual, interactive, or multimedia content (interactive demos, data visualizations, diagrams essential to understanding), add a `note` field to the top-level JSON output: `"note": "This compression captures text content only. The original includes [interactive demos / diagrams / videos] that cannot be represented in text."` This sets reader expectations without pretending the compression is complete.

**Test:** if removing a sentence changes what the reader would do or believe, it stays. If it only changes how entertained or persuaded they feel, it goes.

**Autoresearch after compression:** After the post-compression scan, run single-variable iteration to fix any issues found. For each issue: make ONE change, verify it improves accuracy or completeness without degrading compression ratio, keep or discard. Stop when no single change can improve overall quality by a meaningful margin (delta <0.3 on a 10-point scale). This is not optional. Every compression gets at least one autoresearch pass before rendering to HTML.

### Output JSON schema

Produce this exact JSON structure (do not wrap in markdown code fences, output raw JSON):

```json
{
  "title": "Article Title",
  "source": "domain.com",
  "originalWordCount": 3200,
  "sections": [
    {
      "type": "process",
      "format": "checklist",
      "title": "Section Title",
      "content": {
        "groups": [
          {
            "label": "Group Label (optional)",
            "items": ["Item 1", "Item 2"]
          }
        ]
      }
    },
    {
      "type": "argument-sequential",
      "format": "reasoning-chain",
      "title": "Section Title",
      "content": {
        "steps": ["A because B", "B leads to C", "Therefore D"]
      }
    },
    {
      "type": "argument-parallel",
      "format": "key-points",
      "title": "Section Title",
      "content": {
        "points": ["Independent claim 1", "Independent claim 2"]
      }
    },
    {
      "type": "framework",
      "format": "table",
      "title": "Section Title",
      "content": {
        "headers": ["Column 1", "Column 2", "Column 3"],
        "rows": [
          ["Cell 1", "Cell 2", "Cell 3"]
        ]
      }
    },
    {
      "type": "sequence",
      "format": "numbered-steps",
      "title": "Section Title",
      "content": {
        "steps": ["Step 1 text", "Step 2 text"]
      }
    },
    {
      "type": "concept-causal",
      "format": "concept-map",
      "title": "Section Title",
      "content": {
        "mermaid": "graph TD\n  A[Concept A] --> B[Concept B]\n  B --> C[Concept C]"
      }
    },
    {
      "type": "concept-hierarchical",
      "format": "mindmap",
      "title": "Section Title",
      "content": {
        "mermaid": "mindmap\n  root((Central Concept))\n    Branch A\n      Sub A1\n      Sub A2\n    Branch B\n      Sub B1"
      }
    },
    {
      "type": "decision-tree",
      "format": "flowchart",
      "title": "Section Title",
      "content": {
        "mermaid": "graph TD\n  A{Decision?} -->|Yes| B[Do X]\n  A -->|No| C[Do Y]"
      }
    },
    {
      "type": "catalog",
      "format": "reference-table",
      "title": "Section Title",
      "content": {
        "headers": ["Item", "Description"],
        "rows": [
          ["Item 1", "Brief description"],
          ["Item 2", "Brief description"]
        ]
      }
    },
    {
      "type": "chronology",
      "format": "timeline",
      "title": "Section Title",
      "content": {
        "events": [
          { "year": "2020", "items": ["Event A"] },
          { "year": "2021", "items": ["Event B", "Event C"] },
          { "year": "2023", "items": ["Event D"] }
        ]
      }
    },
    {
      "type": "interaction",
      "format": "sequence-diagram",
      "title": "Section Title",
      "content": {
        "mermaid": "sequenceDiagram\n  Actor A->>Actor B: Action 1\n  Actor B-->>Actor A: Response\n  Actor A->>Actor C: Action 2"
      }
    },
    {
      "type": "quadrant",
      "format": "quadrant-chart",
      "title": "Section Title",
      "content": {
        "mermaid": "quadrantChart\n  title Title\n  x-axis Low X --> High X\n  y-axis Low Y --> High Y\n  quadrant-1 Q1 Label\n  quadrant-2 Q2 Label\n  quadrant-3 Q3 Label\n  quadrant-4 Q4 Label\n  Item A: [0.8, 0.7]\n  Item B: [0.3, 0.6]"
      }
    },
    {
      "type": "data-breakdown",
      "format": "pie-chart",
      "title": "Section Title",
      "content": {
        "mermaid": "pie title Distribution\n  \"Category A\" : 45\n  \"Category B\" : 30\n  \"Category C\" : 25"
      }
    },
    {
      "type": "data-comparison",
      "format": "bar-chart",
      "title": "Section Title",
      "content": {
        "mermaid": "xychart-beta\n  title Comparison\n  x-axis [\"A\", \"B\", \"C\", \"D\"]\n  y-axis \"Value\" 0 --> 100\n  bar [85, 62, 45, 90]"
      }
    },
    {
      "type": "transformation",
      "format": "before-after",
      "title": "Section Title",
      "content": {
        "headers": ["Before", "After"],
        "rows": [
          ["Old state 1", "New state 1"],
          ["Old state 2", "New state 2"]
        ]
      }
    },
    {
      "type": "experience",
      "format": "user-journey",
      "title": "Section Title",
      "content": {
        "mermaid": "journey\n  title User Journey\n  section Phase 1\n    Step A: 5: Actor\n    Step B: 3: Actor\n  section Phase 2\n    Step C: 1: Actor\n    Step D: 4: Actor"
      }
    }
  ]
}
```

The `format` field should reflect the user's settings. If `globalPreference` is `visual`, prefer concept-map, mindmap, and flowchart when a section could go either way. If `text`, prefer prose and checklist.

## Step 4: Render HTML

**IMPORTANT: Use the template, don't rewrite it.** Read the template from `~/Projects/incompressible/templates/output.html` using the Read tool. Then generate only the section HTML and sidebar nav, and do string replacement on the template placeholders. Do NOT write the full CSS/JS from memory — the template is the source of truth for styles. This keeps output files consistent with the template and reduces the amount of content you need to generate.

Generate the sidebar navigation. For each section, create a short-titled anchor link (abbreviate long titles to fit ~15 chars):

```html
<a href="#section-1" class="active"><span class="num">1</span>Short Title</a>
<a href="#section-2"><span class="num">2</span>Short Title</a>
```

Replace `{{SIDEBAR_NAV}}` in the template with the generated sidebar links. The first link gets `class="active"` by default.

Generate the HTML for each section based on its format. Each section div must include an `id` attribute matching the nav anchor (e.g., `id="section-1"`):

**checklist:**
```html
<div class="section" id="section-1">
  <div class="section-label">
    <span class="section-type">{{TYPE}}</span>
    <span class="section-format">· Checklist</span>
  </div>
  <h2>{{TITLE}}</h2>
  <div class="checklist">
    <!-- For each group: -->
    <div class="group">
      <div class="group-label">{{GROUP_LABEL}}</div>
      <!-- For each item: -->
      <div class="item">☐  {{ITEM}}</div>
    </div>
  </div>
</div>
```

**reasoning-chain:**
```html
<div class="section" id="section-N">
  <div class="section-label">
    <span class="section-type">{{TYPE}}</span>
    <span class="section-format">· Chain</span>
  </div>
  <h2>{{TITLE}}</h2>
  <div class="reasoning-chain">
    <!-- Render steps joined with → arrows: -->
    <p>{{STEP_1}} <span class="arrow">→</span> {{STEP_2}} <span class="arrow">→</span> {{STEP_3}}</p>
  </div>
</div>
```

**key-points:**
```html
<div class="section" id="section-N">
  <div class="section-label">
    <span class="section-type">{{TYPE}}</span>
    <span class="section-format">· Key Points</span>
  </div>
  <h2>{{TITLE}}</h2>
  <div class="key-points">
    <ul>
      <!-- For each point: -->
      <li>{{POINT}}</li>
    </ul>
  </div>
</div>
```

**prose** (use sparingly — only when chain notation loses meaning):
```html
<div class="section" id="section-N">
  <div class="section-label">
    <span class="section-type">{{TYPE}}</span>
    <span class="section-format">· Prose</span>
  </div>
  <h2>{{TITLE}}</h2>
  <div class="prose">
    <!-- For each paragraph (ONE idea per paragraph): -->
    <p>{{PARAGRAPH}}</p>
  </div>
</div>
```

**table:**
```html
<div class="section" id="section-N">
  <div class="section-label">
    <span class="section-type">{{TYPE}}</span>
    <span class="section-format">· Table</span>
  </div>
  <h2>{{TITLE}}</h2>
  <table class="data-table">
    <thead><tr><!-- th for each header --></tr></thead>
    <tbody><!-- tr/td for each row --></tbody>
  </table>
</div>
```

**numbered-steps:**
```html
<div class="section" id="section-N">
  <div class="section-label">
    <span class="section-type">{{TYPE}}</span>
    <span class="section-format">· Steps</span>
  </div>
  <h2>{{TITLE}}</h2>
  <div class="numbered-steps">
    <ol><!-- li for each step --></ol>
  </div>
</div>
```

**flowchart / concept-map / mindmap:**
```html
<div class="section" id="section-N">
  <div class="section-label">
    <span class="section-type">{{TYPE}}</span>
    <span class="section-format">· {{Flowchart|Concept Map|Mind Map}}</span>
  </div>
  <h2>{{TITLE}}</h2>
  <div class="mermaid-container">
    <pre class="mermaid">{{MERMAID_CODE}}</pre>
  </div>
</div>
```

**reference-table** (for catalog type — uses same table styling):
```html
<div class="section" id="section-N">
  <div class="section-label">
    <span class="section-type">{{TYPE}}</span>
    <span class="section-format">· Reference</span>
  </div>
  <h2>{{TITLE}}</h2>
  <table class="data-table">
    <thead><tr><!-- th for each header --></tr></thead>
    <tbody><!-- tr/td for each row --></tbody>
  </table>
</div>
```

**timeline** (custom HTML, not Mermaid — simpler, more legible, no external dependency):
```html
<div class="section" id="section-N">
  <div class="section-label">
    <span class="section-type">{{TYPE}}</span>
    <span class="section-format">· Timeline</span>
  </div>
  <h2>{{TITLE}}</h2>
  <div class="timeline">
    <!-- For each event: -->
    <div class="timeline-event">
      <div class="timeline-year">{{YEAR}}</div>
      <ul class="timeline-details">
        <li>{{ITEM}}</li>
      </ul>
    </div>
  </div>
</div>
```

**sequence-diagram / quadrant-chart / pie-chart / bar-chart / user-journey** (all Mermaid-based — use same container as flowchart/concept-map):
```html
<div class="section" id="section-N">
  <div class="section-label">
    <span class="section-type">{{TYPE}}</span>
    <span class="section-format">· {{Sequence|Quadrant|Pie Chart|Bar Chart|Journey}}</span>
  </div>
  <h2>{{TITLE}}</h2>
  <div class="mermaid-container">
    <pre class="mermaid">{{MERMAID_CODE}}</pre>
  </div>
</div>
```

**before-after** (uses table styling with two columns):
```html
<div class="section" id="section-N">
  <div class="section-label">
    <span class="section-type">{{TYPE}}</span>
    <span class="section-format">· Before / After</span>
  </div>
  <h2>{{TITLE}}</h2>
  <table class="data-table">
    <thead><tr><th>Before</th><th>After</th></tr></thead>
    <tbody><!-- tr/td for each row --></tbody>
  </table>
</div>
```

Replace the template placeholders:
- `{{ARTICLE_TITLE}}` — from JSON `title`
- `{{SOURCE}}` — display text for the source (e.g., "x.com (@RayDalio)")
- `{{SOURCE_URL}}` — the original URL the article was fetched from. If raw text was provided, use `#` as the href
- `{{READ_TIME}}` — estimate: compressed word count / 200, rounded up (displayed as just "X min", no "read" suffix)
- `{{ORIGINAL_WORDS}}` — from JSON `originalWordCount`, formatted with commas (e.g., "7,106")
- `{{COMPRESSED_WORDS}}` — count all words in the rendered sections, formatted with commas
- `{{TIME_SAVED}}` — per-article time saved: `(originalWordCount - compressedWordCount) / 200`, formatted as "X min" (under 60) or "X.Y hrs" (60+). Use 0 min floor (never negative)
- `{{MERMAID_SCRIPTS}}` — if any section uses a Mermaid-based format (`concept-map`, `flowchart`, `mindmap`, `sequence-diagram`, `quadrant-chart`, `pie-chart`, `bar-chart`, `user-journey`), replace with `<script src="https://cdn.jsdelivr.net/npm/mermaid/dist/mermaid.min.js"></script><script>mermaid.initialize({ startOnLoad: true, theme: 'dark' });</script>`. Otherwise replace with empty string. Note: `timeline` is custom HTML, not Mermaid, so it does not trigger this script.
- `{{SIDEBAR_NAV}}` — the sidebar navigation links
- `{{SECTIONS}}` — the concatenated section HTML

## Step 5: Track time saved, save, and open

1. Calculate time saved for this article: `(originalWordCount - compressedWordCount) / 200` minutes.
2. Read `~/Projects/incompressible/stats.json`. If it doesn't exist, create it with `{"totalMinutesSaved": 0, "articles": []}`. Add this article's time saved to `totalMinutesSaved` and append an entry to `articles`: `{"title": "...", "filename": "...", "source": "...", "originalWords": N, "compressedWords": N, "date": "YYYY-MM-DD"}`. Write the file back.
3. Format the total for display: under 60 min show as "X min" (e.g., "42 min"). 60+ min show as "X.Y hrs" (e.g., "2.3 hrs"). Use this value for `{{TOTAL_TIME_SAVED}}` on the index page. For the article page, calculate per-article time saved: `(originalWordCount - compressedWordCount) / 200`, same formatting rules. Use this for `{{TIME_SAVED}}`.
4. Generate a filename: `YYYY-MM-DD-slugified-title.html` (e.g., `2026-03-23-how-to-fix-your-life-in-one-day.html`)
5. Ensure `~/Projects/incompressible/` exists (create if needed)
6. Write the complete HTML to `~/Projects/incompressible/{{filename}}`
7. Regenerate the index page: read the index template from `~/Projects/incompressible/templates/index.html`. For each entry in `stats.json`'s `articles` array (newest first), generate a list item:
   ```html
   <li class="article-item">
     <div class="article-info">
       <a href="{{filename}}">{{title}}</a>
       <div class="article-meta">{{source}} · {{date}}</div>
     </div>
     <span class="article-read-time">{{readTime}} min</span>
   </li>
   ```
   Replace `{{ARTICLE_LIST}}` with the concatenated list items, `{{ARTICLE_COUNT}}` with the number of articles, and `{{TOTAL_TIME_SAVED}}` with the formatted total. Write to `~/Projects/incompressible/index.html`.
8. Open the article in the browser: `open ~/Projects/incompressible/{{filename}}`
9. Tell the user: "Compressed **{{title}}** from {{originalWords}} → {{compressedWords}} words. Opened in browser."
