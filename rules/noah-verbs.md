# Noah Verbs (MANDATORY)

Shorthand commands Noah can type to activate distinct operational modes. Short verbs are specified inline below. Long ones (`noahbot`, `noahfix`) live in their own files.

## The Verbs

| Verb | Mode | Spec |
|------|------|------|
| `noahloop` | Decide: 5-step shortest-path framework | inline below |
| `noahplan` | Plan deep, no code until confirmed | inline below |
| `noahship` | Full deploy pipeline with gates | inline below |
| `noahcut` | Dead-code deletion pass | inline below |
| `noahbot` | Orchestrator: delegate + handoff | `.claude/reference/context-discipline.md` |
| `noahfix` | Autonomous debug, no user checks | `.claude/reference/noahfix.md` |
| `noahwatch` | Live process observation + correlated summary | `.claude/reference/noahwatch.md` |

## How to invoke

Say the verb anywhere in a message. It activates that mode for the current task.

```
noahfix the dashboard is showing empty scorecards
noahplan GA4 conversion tracking pipeline
noahship
```

## Composable

Verbs stack. `noahbot` + `noahplan` = plan deep, then delegate. `noahfix` + `noahship` = debug, fix, then deploy. Most restrictive gate wins when verbs conflict.

## Without invocation

Baseline defaults fire automatically:
- `noahloop` — any non-trivial decision
- `noahbot` — tasks touching >2 files or >100 lines
- `noahplan` — features (code can start before explicit confirmation)
- `noahship` — any deploy command
- `noahfix` — Noah reports a bug
- `noahcut` — weekly cleanup
- `noahwatch` — opt-in only (not yet auto-firing); explicit invocation activates

Explicit invocation upgrades defaults to **hard gates**.

---

## `noahloop` — Shortest Path

**Gate:** Reversible in under an hour? Just do it. Expensive to undo? Run all 5 steps.

1. **Gap** — what exists → what needs to exist, in one sentence. Can't write one? Trace the system first, produce N gap sentences, then noahloop each. Ship order = Step 4's ranking across all gaps.
2. **Path** — trace what's built, including off-path alternatives (other layers that could serve the same need). Count the boundaries. Which are unnecessary?
3. **Beliefs** — what are you assuming? Verify only what would change your answer. Two defaults to always challenge:
   - The fix must live in the layer where the symptom fires.
   - The current code is the design — a half-built pattern is usually the real design in draft; finish it instead of patching around it.
4. **Decide** — fewest unnecessary verified boundaries > fastest for user > cheapest > least code.
5. **Break** — attack the plan. Breaks → loop to 2. Holds → ship it.

---

## `noahplan` — Deep Plan

Produce a complete implementation plan. No code until Noah confirms.

1. **Research** — delegate to Explore agents. Gather file paths, current behavior, data shapes.
2. **Gap analysis** — what exists vs. what needs to exist (noahloop Step 1, exhaustive).
3. **Write the plan** — numbered items, each with: exact file paths, current → target state, testable AC, `parallel: true/false` + dependencies, estimated line count.
4. **Identify phases** — independently-shippable groups, each own commit boundary.
5. **Attack the plan** — run noahloop Step 5 (Break) against each phase.
6. **Present** — show Noah. Wait for confirmation.
7. **On confirmation** — if `noahbot` is active, delegate. Otherwise, execute in main context.

**Plan is NOT ready if:** any item lacks file paths, any AC is "it works", items marked parallel actually depend on each other, >1,500 lines without phase splits, no phase ships independently.

**Hard rule:** NO CODE until confirmed. Zero. The plan IS the deliverable until Noah says go.

---

## `noahship` — Deploy Gate

Run the full pipeline in order. No skipping.

1. **Test gate** — `cd api && npm run test:deploy` must exit 0. Output visible in this turn. (Changed-file tests only; `npm test -- --run` for full suite.)
2. **Exercise gate** — walk the affected user-flow (curl for API, qa-explore for frontend). Evidence in this turn.
3. **Deploy** — run the deploy command for the affected target(s).
4. **Post-deploy verify** — re-exercise against production to confirm the deploy landed.

Any step failure blocks the deploy. Surface it, don't skip it.

Full deploy rules, overrides, evidence: `.claude/reference/deploy-windows.md` + `.claude/reference/deploy-windows-evidence.md`.

---

## `noahcut` — Deletion Pass

Find and remove dead code. No new features, no logic refactors — only deletions.

1. **Scan** — `cd api && npx knip`, `cd frontend && npx knip`, `git log --diff-filter=D --summary --since="1 week ago"`.
2. **Triage** —
   - *Safe:* zero call sites, no dynamic dispatch, no E2E reference.
   - *Needs confirmation:* `api/src/lib/` files (may be cron/queue), DB tables/columns, exported `index.js` members.
   - *Protected:* anything in `project_unshipped_infra.md` (feature-gate, site-limit, kek-rotation).
3. **Present** — show Noah the triage list. Wait for confirmation on the needs-confirmation set.
4. **Delete** — one commit per logical group, `chore(cleanup):` or `refactor(cleanup):` prefix.
5. **Verify** — `cd api && npm test -- --run` to confirm nothing broke.

**Targets (priority order):** zero-call-site functions → unreferenced Vue components → commented-out code >1mo → feature flags 100% on/off 30+ days → duplicate helpers → stale TODOs → unused env vars → unused npm deps.

**Hard rule:** deletion commits are standalone — never bundled into feature commits. Independently revertable.
