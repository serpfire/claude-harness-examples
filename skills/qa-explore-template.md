---
name: qa-explore
description: Autonomous page & workflow testing. Authenticate to your deployed app, navigate, take screenshots, READ the screenshots, inspect API responses, report findings — with zero user involvement.
type: skill
---

# qa-explore — Autonomous Visual QA

Test any page or workflow in your deployed application by having Claude log in, navigate, take screenshots, **read its own screenshots**, inspect API responses, interact with elements, and report findings. **The user does nothing.**

This is a template — adapt the auth flow, target URL patterns, and test runner to match your stack.

## Why this pattern matters

Most "AI testing" skills stop at running the test. This skill is different: **Claude reads the screenshots and reasons about what it sees.** That's the advanced layer — skills that read their own output.

Apply this to anything visual:
- Reports (does every chart render? is any panel blank?)
- Dashboards (do filters work? does pagination return data?)
- Client deliverables (does the PDF export match the web view?)
- Onboarding flows (does each step load? do errors appear correctly?)

## Arguments

- `$1` — Target: URL path (e.g., `/app/reports`), workflow name, or `"smoke"` for full-site pass
- `$2` — Optional: additional context (site ID, user role, filter params)

## The autonomous flow

You are a fully autonomous QA explorer. You authenticate, navigate, capture, screenshot, **READ the screenshots**, and report. The user never reloads, checks network tabs, grants permissions, or takes any action.

### 1. Check for an existing test spec

Before writing a new test, check if one already exists for the target:

```bash
# Adjust path to match your test directory
ls YOUR_E2E_DIR/tests/qa-*.spec.js | grep $TARGET_SLUG
```

If a matching spec exists, just run it. Only write a new spec if none exists. Saves tokens on repeat runs.

### 2. Run the test

```bash
# Generic Playwright invocation — adapt to your config
cd YOUR_E2E_DIR
npx playwright test --project=qa tests/qa-TARGET.spec.js --timeout=120000
```

### 3. READ THE SCREENSHOTS

**This is the whole point.** After every test run, use the Read tool on every screenshot captured:

```
Read YOUR_E2E_DIR/test-results/qa-01-initial-load.png
Read YOUR_E2E_DIR/test-results/qa-02-after-filter.png
Read YOUR_E2E_DIR/test-results/qa-03-empty-state.png
```

If you take a screenshot and don't look at it, you haven't tested anything.

### 4. Report findings

For each screenshot, report:
- What rendered correctly
- What's missing, broken, or suspicious
- API responses that don't match the visual state (e.g., API returned data but chart is empty)
- UX issues (overlapping elements, cut-off text, empty containers)

End with a triage: `PASS` / `PARTIAL (with issues)` / `FAIL (blocking)`.

---

## Template: writing a new QA spec

```javascript
import { test } from "@playwright/test"
import { authenticateProduction } from "../helpers/YOUR-auth-helper.js"
import { createConsoleMonitor } from "../helpers/console-monitor.js"

const TARGET = "/app/YOUR-PAGE"
const CONTEXT = { /* site ID, user role, filter params */ }

test.describe("YOUR PAGE — QA Explorer", () => {
  test("full exploration", async ({ browser }) => {
    const context = await browser.newContext({ viewport: { width: 1440, height: 900 } })
    const page = await context.newPage()
    const monitor = createConsoleMonitor(page)

    // 1. Authenticate to the deployed environment
    await authenticateProduction(page)

    // 2. Navigate to target
    await page.goto(`${process.env.APP_URL}${TARGET}`)
    await page.waitForLoadState("networkidle")

    // 3. Capture initial load
    await page.screenshot({ path: "test-results/qa-01-initial-load.png", fullPage: true })

    // 4. Inspect API responses
    const apiResponses = await page.evaluate(() => {
      return window.__apiResponseLog || []
    })
    console.log("API responses:", JSON.stringify(apiResponses, null, 2))

    // 5. Interact with elements
    // Click filters, change date ranges, apply selections — whatever the workflow requires
    await page.click('[data-test="filter-toggle"]')
    await page.waitForTimeout(500)
    await page.screenshot({ path: "test-results/qa-02-after-filter.png", fullPage: true })

    // 6. Check console errors
    const errors = monitor.getErrors()
    if (errors.length) console.log("Console errors:", errors)

    // 7. More interactions + screenshots as the workflow requires
    // ...

    await context.close()
  })
})
```

## Auth helper pattern

Keep auth logic in a shared helper. Never copy-paste auth into specs — when your auth changes (token format, provider migration, session TTL), you fix one file.

```javascript
// helpers/YOUR-auth-helper.js
export async function authenticateProduction(page) {
  // Use a pre-issued test-user token, or automated login flow
  // Never hardcode credentials — pull from env vars or a gitignored .env
  const token = process.env.QA_TEST_TOKEN
  await page.goto(process.env.APP_URL)
  await page.evaluate((t) => {
    // Set token in whatever storage your auth lib uses
    localStorage.setItem("auth_token", t)
  }, token)
}
```

## The iterative debug-fix loop

When qa-explore finds a bug, don't stop — **enter a debug loop**:

1. qa-explore runs → finds issue
2. Diagnose by reading the failing screenshot + console log + API response
3. Propose fix
4. Apply fix
5. Re-run qa-explore
6. Confirm fix in the new screenshot
7. If still broken: loop to step 2 with new evidence

This is the autonomous debugging discipline. Most people stop at step 1. The advanced discipline is running the whole loop without human intervention.

## Installation

1. Copy this file to `~/.claude/skills/qa-explore/SKILL.md` or `.claude/skills/qa-explore/SKILL.md` (project-local).
2. Set up Playwright with a `qa` project in your `playwright.config.js`.
3. Create the auth helper and console monitor helpers.
4. Store your test-user credentials in a gitignored `.env`.
5. Invoke with `/qa-explore /app/your-page`.

## What you're buying when you install this

- Automated visual verification before every ship
- A pattern your future self can extend (more specs, more targets, fewer surprises)
- Skills-that-read-their-own-output as a reusable mental model for other automation

## Shared with the SEO Week NYC 2026 "Scars" talk

This is a sanitized template. The original lives in Noah Learner's harness and ships with live auth to his production app. Everything specific to his stack has been stripped; everything teachable remains.
