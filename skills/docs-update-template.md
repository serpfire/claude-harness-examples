---
name: docs-update
description: Generate and maintain living user-facing documentation from source code. Reads views + API routes, writes markdown, captures and optimizes screenshots, keeps docs in sync with the UI automatically. Template — adapt the registry shape, view-file pattern, and screenshot runner to match your stack.
type: skill
---

# docs-update — Living Docs From Source Code

Most in-app documentation is stale before it ships. Someone wrote it once, renamed a button, and the doc is now lying to your users. This skill fixes the ongoing version of that problem: **every time a feature changes, the doc regenerates from the current code.** Markdown content + screenshots, both kept honest.

This is a template — adapt the registry shape, view-file layout, and screenshot runner to your stack.

## Why this pattern matters

**Every support ticket is a design failure.** A stale doc is worse than no doc — it teaches the user to ignore your docs. A living doc, regenerated from code when the code changes, means your help center is always the truth of what the app does today.

Typical results from adopting this pattern:
- Help-center staleness drops from "most of it" to "none of it"
- Support queue shrinks — users get answers from the UI they're already looking at
- Every new feature ships with docs, automatically, not "I'll write docs later"
- Screenshots in your docs always match the current UI — no more "this screenshot is from 2 redesigns ago"

## Architecture

This skill needs four things to exist in your codebase. The names are suggestions; adapt them to your conventions:

| What | Purpose | Suggested location |
|---|---|---|
| **Doc registry** | Maps feature slug → source files + route + metadata | `<app>/docs/index.js` or similar |
| **File→doc map** | Maps source file path → affected doc slugs (for staleness detection) | Same file, separate export |
| **Markdown home** | Where rendered docs live | `<app>/docs/sections/<section>/<slug>.md` |
| **Screenshot runner** | A test/script that opens the app and captures per-slug screenshots | e.g., Playwright spec, Puppeteer script |

The skill is **deliberately agnostic** about framework. It works for Vue + Pinia, React + Redux, Next.js, Svelte, plain static sites — anywhere you have "a view file, a route, and a place to store markdown."

## Installation

Save this file to `~/.claude/commands/docs-update.md` (user-global) or `<repo>/.claude/commands/docs-update.md` (project-scoped). Invoke with `/docs-update <mode> <target>`.

## Modes

### `check` — report stale docs (read-only)

Diffs recent file changes against the file→doc map and reports which docs need regeneration. No writes. Run this after any feature commit.

```
/docs-update check
```

Output: list of `<slug>` values whose source files changed since the doc's `lastVerified` date.

### `generate <slug>` — full pipeline (code → markdown → screenshot)

The core workflow. Read the code, write the doc, capture the screenshot, optimize, verify.

```
/docs-update generate dashboard
```

See "The full generation pipeline" below.

### `generate-all` — bulk initial population

Replaces all stub docs with real content. Dispatches up to 5 subagents in parallel, one per slug. See "Generate all" below.

### `update <slug>` / `update-all` — refresh existing docs

Diff the current code against the current doc, update only inaccurate sections, preserve the rest. Screenshot regenerated only if UI changed materially.

### `screenshots` — regenerate all screenshots

Runs the screenshot runner across every slug. Useful after a design-system change, theme update, or layout refactor.

### `bootstrap <slug>` — scaffold a new feature's docs

Creates the registry entry, the markdown file, and the screenshot-runner entry for a new feature. Then you run `generate <slug>` to fill in real content.

## The full generation pipeline (mode: `generate <slug>`)

### Step 1: Read the source code

1. Look up `<slug>` in the doc registry.
2. Read the view file(s) — understand the template, computed properties, and user interactions.
3. Read the API route handler(s) — understand what data the page fetches and what it does with user input.
4. Read the store/state-management file if the view uses complex state.
5. **You are reading real source code, not making anything up.** The doc must describe what the code actually does.

### Step 2: Analyze the UI

From the view, identify:
- **Layout structure** — what cards, sections, panels does the user see?
- **Interactive elements** — buttons, tabs, filters, dropdowns, modals, date pickers
- **Data displays** — tables, charts, KPI cards, lists
- **Navigation** — where did the user come from, where can they go next?
- **Error states** — what happens when data is empty, loading fails, permissions are missing?
- **Feature gates** — is this feature behind a flag? Tier-gated?

### Step 3: Write the markdown

Write to `<app>/docs/sections/<section>/<slug>.md`:

```markdown
# {Feature Title}

{1-2 sentence description of what this feature does and why the user cares.}

![{Feature Title}]({slug}.webp)

## What You See

{Describe the page layout — what the user sees when they land here. Reference specific UI elements: cards, tables, charts, tabs. Be concrete — "a grid of KPI cards showing clicks, impressions, CTR, and position" not "some metrics."}

## How to Use

1. {Step-by-step instructions for the primary workflow}
2. {Reference specific buttons, menu items, and interactions}
3. {Include conditional paths — "If you have multiple accounts, select one from the top bar"}

## Key Actions

- **{Action name}** — {what it does, when to use it}
- **{Action name}** — {what it does}

## Tips

> **Tip:** {Practical advice that saves the user time or prevents mistakes}

> **Tip:** {Another tip}

## Common Issues

### {Problem description}
{1-2 sentence explanation of what causes this and how to fix it.}

### {Problem description}
{Explanation and fix.}

## Related Features

- [{Related feature}](/help/{section}/{slug}) — {how it relates}
- [{Related feature}](/help/{section}/{slug}) — {how it relates}
```

### Content rules

- **Describe what IS, not what WILL BE.** Only document current behavior. No "coming soon."
- **Be specific.** "Click the blue **Share** button in the top-right" beats "share the report."
- **Every section should answer "what do I do?"** not just "what is this?"
- **Keep it scannable.** Users skim docs, they don't read novels. Short sentences, lots of bullets.
- **Include the screenshot embed** — `![Title]({slug}.webp)` at the top, right after the one-sentence description.
- **If you have a glossary,** use `<<glossary:term-slug>>` markers (or your system's equivalent). Check the glossary file before using a term — undefined terms should render as plain text, not broken links.

### Step 4: Update the registry

- Update `lastVerified` to today's date in the doc-registry entry.
- Update the `tips` array with 2-3 tips derived from the UI analysis.
- Update the `faq` array with 2-3 common questions based on error states and complex workflows.
- Update `tags` if the feature scope has changed.

### Step 5: Capture the screenshot

If local dev servers are running, invoke your screenshot runner. Example with Playwright:

```bash
<screenshot-runner-command> --grep "screenshot: {slug}"
```

The runner should:
1. Navigate to the route for this slug.
2. Capture a full-res PNG of the content area (exclude persistent sidebar/chrome if any).
3. Optimize to WebP — **quality 80, max 1600px wide, no upscaling** — via `sharp` or equivalent.
4. Save to the location your static-asset server serves from.

**If dev servers are not running:** skip screenshots, report in the output "Screenshots pending — run `/docs-update screenshots` when servers are up." Never commit a stale screenshot as if it were fresh.

### Step 6: Verify

Run your project's build. If the doc added broken imports (new glossary term that doesn't exist, broken relative link), the build will catch it.

```bash
<your-build-command>
```

## Generate-all (mode: `generate-all`)

Initial-population workflow. Replaces all stub docs with real content.

1. Read the full doc registry.
2. For each entry, spawn a background subagent with this prompt:

   > Read the source code for the `{slug}` feature (view: `{viewFile}`, route: `{appRoute}`).
   > Follow the `/docs-update generate {slug}` pipeline to create complete documentation.
   > Write the markdown to `{markdownPath}`.
   > Update the registry entry's tips, FAQ, and `lastVerified` date.

3. **Run up to 5 subagents in parallel** — they're independent.
4. After all complete, run `screenshots` mode to capture every slug.
5. Run the build to verify.

This is the skill's highest-leverage mode. A codebase with 40 features can get 40 real docs in one `generate-all` run, typically 10-20 minutes of wall-clock. Faster than any human-authored help center.

## Check-for-staleness (mode: `check`)

1. Run `git diff --name-only HEAD~5` (or a longer window) to find recently changed files.
2. Read the file→doc map.
3. For each changed file, look up the corresponding doc slug(s).
4. Read the doc registry and check each affected entry's `lastVerified` date.
5. Report which docs are stale, which are current.
6. Recommend: `run /docs-update update <slug>` (or `generate <slug>` if the doc is still a stub) for each stale one.

## When to run this skill

**MANDATORY triggers** (run `/docs-update check` after):

- Created a new view or route
- Added a new tab to an existing view
- Modified an existing view's UI (new buttons, fields, modals)
- Changed navigation structure (sidebar items, route paths)
- Added a new API endpoint users interact with
- Changed onboarding flow steps

**Post-commit timing.** After committing feature work, run `check`. If stale docs found, spawn a background subagent per stale doc. You are not interrupted — agents run in background and report a one-line summary when done.

## Automating the trigger (optional, advanced)

The convention above works if you remember to run `/docs-update check` after feature commits. If you want it truly automatic, add a `PostToolUse` hook on your version control tool (or on `Edit`/`Write`) that checks whether the edited file appears in the file→doc map and, if so, queues a background `update <slug>` task. This turns "skill you run by convention" into "skill that runs when the condition is met" — the next rung up the ladder.

## Screenshot image format

Recommended:
- **Format:** WebP (quality 80, effort 4) — 70-85% smaller than PNG, universally supported
- **Max width:** 1600px (no upscaling on smaller viewports)
- **Capture area:** Content area only — exclude persistent chrome (sidebar, app header) for consistency across docs
- **Viewport:** 1440×900 for consistent captures across environments
- **Display:** A click-to-zoom lightbox is a nice UX touch — thumbnail in the doc, full-size modal on click
- **Storage:** Static assets directory your site already serves. Gitignore if they regenerate reliably; commit if not.

## Safety

- **Never delete existing documentation** — only update or add. The skill should be additive.
- **Preserve markdown structure** — heading hierarchy, section order. A user who's navigated to `## Common Issues` should find it in the same place after regeneration.
- **Always run the build after changes** to verify no broken imports or references.
- **Check the glossary before using glossary markers** — undefined terms render as plain text (or worse, broken links) in most doc renderers.
- **Screenshot regeneration requires live dev servers** — the skill should detect this and skip gracefully if unavailable, not fake it.
- **WebP format** — make sure your doc renderer supports it (all modern browsers do; some legacy static-site generators don't).

## Design notes

**Why "describe what IS, not what WILL BE"?** The #1 failure mode of doc systems is documenting planned features. The doc promises a button that doesn't exist, or a flow that was scoped out at the last minute. Regenerating from code makes this failure mode impossible — if it's not in the code, it can't be in the doc.

**Why per-slug subagents in `generate-all`?** Each feature's doc is independent. Sequential generation wastes wall-clock. 5-way parallelism is the sweet spot for most machines — fast without exhausting the parent context or saturating the API.

**Why bootstrap creates the scaffolding before generate fills it?** Two-step authoring matches the actual workflow: "I'm adding a feature" (bootstrap) is a distinct moment from "I'm writing its docs" (generate). Forcing them together creates friction at the moment where you're least able to afford it (when the feature is still half-built).

**Why WebP at quality 80?** Empirically the knee of the quality-vs-size curve. 80 is visually indistinguishable from lossless for UI screenshots; 70 starts showing artifacts; 90 is huge for no visible gain.

## Related

- **A `feature-registry.md` rule.** If you have a rule that says "every new view must have a registry entry," `/docs-update bootstrap` is what it runs. Pair the rule (teaches) with the skill (automates) and the convention stops drifting.
- **A `zero-support-design` rule.** If "every support ticket is a design failure" is in your harness, living docs are one of the mechanisms that actually deliver it — users answer their own questions because the docs are current.
- **A screenshot-reading skill** (like `qa-explore`). If you already capture screenshots for QA, the same infrastructure can populate your help center. Two outputs, one investment.

## Example registry shape (adapt to your stack)

```javascript
// <app>/docs/index.js

export const DOC_REGISTRY = {
  dashboard: {
    title: "Dashboard",
    section: "overview",
    appRoute: "/app/dashboard",
    lastVerified: "2026-04-23",
    tags: ["core", "metrics"],
    tips: [
      "Click any KPI card to drill into the underlying data.",
      "Use the date picker to change the comparison window.",
    ],
    faq: [
      { q: "Why are my numbers zero?", a: "Your data pipeline may still be running. Check the Jobs page." },
    ],
  },
  // ... more entries
};

export const FILE_DOC_MAP = {
  "src/views/DashboardView.vue": ["dashboard"],
  "src/api/routes/dashboard.js": ["dashboard"],
  "src/stores/dashboard.js": ["dashboard"],
  // ... more mappings
};
```

That's the minimum shape. Extend with whatever fields your doc renderer needs.
