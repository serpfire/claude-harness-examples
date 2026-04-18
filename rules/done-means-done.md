# Done Means Done (MANDATORY)

Two phases. Both must pass before claiming "done," "shipped," "complete," "finished," "ready," "wrapped up," or "all set."

Evidence, history, canonical violations, compliant template: `.claude/reference/done-means-done-evidence.md`.

## Phase A — Before coding: solve it right

Override the minimal-diff instinct. Goal = complete, elegant solution within the problem being solved (not scope creep, but full coverage of the reported root cause).

**Severity gate:**
- **Full (all 6 steps)** — resilience, error handling, data flow, user-facing state, infra, anything where "works most of the time" is unacceptable.
- **Abbreviated (Steps 2 + 5)** — simple contained fixes (CSS, typo, single-function logic) with bounded failure surface.
- **Skip** — mechanical changes explicitly dictated.

**Steps:**
1. **Hindsight from 1 year out** — imagine live 12 months. User complaints, admin burden, cost, data debt, edge cases at scale.
2. **Map the full problem surface** — find ALL manifestations of the underlying cause (other page types, roles, entry points, network conditions, timing windows, data states).
3. **Define ideal outcome per failure path** — usually "user never notices." End users: zero config, smart defaults, invisible recovery. Admins: self-maintaining, silence = healthy.
4. **Find the elegant solution** — ONE design that prevents ALL failure paths. **Intervention hierarchy (prefer higher):** (1) prevent entirely, (2) intercept at framework/system level, (3) catch globally, (4) recover after the fact. **Hard stop: solution at level 3 or 4 when level 1 or 2 achievable = not done.**
5. **Check for gaps** — timing (polling, races, stale state), scope (one context covered not others), context (handler lacks info for proper recovery).
6. **Present analysis, then build** — briefly state failure paths found, intervention level chosen, gaps closed. Demonstrates complete thinking before code.

**Circuit-breaker:** if mid-implementation you think "I should also handle X" — STOP. Go back to Step 2, redo with X included.

**Litmus test:** "If I ship this, will the user need a follow-up conversation?" If yes for any reason = not done.

## Phase B — Before claiming done: preconditions + 5 checks

### Preconditions

**P1 — scale.** Sum `git diff --stat`. If >500 lines, run the 5 checks **per logical phase**, separate done message per phase. A "phase" ships independently (route+tests+curl; view+composable+qa-explore; migration+route+query).

**P2 — plan enumerability.** Plan is (1) numbered items, (2) each with one-sentence AC, (3) no narrative-only plans. Without this, Check 1 is uncomputable.

### Check 1 — Plan completeness

Each plan item: name what shipped (`<hash> <file:line>`) OR explicitly `skipped: <reason>`. If spec names a location, grep to confirm implementation lives there — if elsewhere, surface `deviated: <item> shipped to <actual> instead of <spec>`.

### Check 2 — No stubs

Grep changed files for stubs introduced by this work: empty bodies, `TODO/FIXME/XXX` you added, `throw new Error("not implemented")`, placeholder returns, empty templates, commented-out scaffolding.

### Check 3 — Tests cover ACs

Endpoint or critical-flow work requires tests that (a) exist (shape-assertion floor — see `testing.md`), (b) are green (`npm test` exits 0 this session), (c) cover each AC. For each AC, name the specific test. Uncovered ACs = `uncovered AC: <item> — no test asserts this`.

### Check 4 — Exercise like a user — HARD GATE

Tests existing is necessary but not sufficient. Before claiming done, exercise through the interface a user touches:

- **Frontend:** `qa-explore` skill (NOT `dev-browser` — can't handle Clerk). Log in, click buttons, confirm data not empty/stale/errored.
- **API:** `curl` (or `ctx_execute` with `fetch`) against the deployed Worker with a real JWT (`e2e/.env`). Inspect full response — not `[]`, `{}`, stubs, or `_diagnostic.errors`.
- **Pipeline:** trigger, wait, query output store (BQ/D1/KV/R2) for the expected row/blob.
- **Schema:** query with `wrangler d1 execute --remote` or `bq query` against known-good fixture. Shape AND non-empty rows.
- **Library/pure function:** `ctx_execute` with realistic input.

**HARD GATE — Check 4 evidence MUST be in the same message as the done claim.** No curl output / screenshot reference / query result / function output = rejected. Evidence is concrete output. "I tested it" / "I verified" / "test passes" describe assertion, not output.

### Check 5 — Noah-correction sweep

Sweep last 24h for terse corrections: `still no` / `still doesn't` / `still broken` / `NO` / `I didn't ask` / `you missed` / `you forgot` / `wrong` / `I want every` / `I want all` / `as I said earlier` / `again`.

For each hit: does the current done message address it? Unaddressed = `unaddressed Noah correction: "<quote>" — fixed in / not fixed because <reason>`.

## What "done" must include

0. **Preconditions:** P1 (line count + per-phase) and P2 (plan enumerable, ACs) named explicitly.
1. **Phase A summary** when severity gate required it — failure paths found, intervention level chosen, gaps closed.
2. **Plan items** with status (shipped `<hash> <path>`, `skipped: <reason>`, or `deviated:`).
3. **Stub check:** none introduced, OR explicit list with follow-up commitment.
4. **Tests:** which cover new code, pass/fail counts, uncovered ACs if any.
5. **Exercise evidence:** concrete output. Curl response, screenshot path, query result, function output.
6. **Noah-correction sweep:** "no unaddressed corrections" OR list each with status.

Template: see evidence sidecar.

## Refused done claims

- Done message without Check 4 evidence in the same message
- Skipped Phase A when severity gate required
- Level-3/4 intervention when level-1/2 achievable
- >500 lines without per-phase structure (P1)
- Narrative-only plan (P2)
- Any spec item unaccounted for
- Any introduced stub
- Endpoint/critical-flow work with missing or red tests, or uncovered ACs
- Spec items shipped to wrong location without `deviated:` annotation
- Unaddressed Noah corrections from last 24h
- Claude can't list the plan items

## Override

Per-task: `"override done — <reason>"`. Single-instance; next done claim full check.

**Acceptable:** partial WIP commit with gaps surfaced, tests intentionally next commit, draft for review.

**Not acceptable** (refused even with override): "mostly done", "I'll fix the stub later", "tests are flaky".
