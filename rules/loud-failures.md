# Loud Failures

Silent degradation is the most expensive bug class in most codebases. Every fix-wave I've ever been through starts the same way: *the system kept running but produced wrong or empty output without surfacing why.* These four sub-rules force failures into visibility.

They share one root cause — **the system continued executing after partial failure without telling anyone** — and that's why they live in one file. One root cause, one rule to remember.

## 1. No `Promise.all` with `.catch(() => [])`

Use `Promise.allSettled` and log every rejection. If partial success is acceptable, return both `data` and a `_diagnostic.errors[]` field. Never silently substitute `[]` for a failed fetch — the empty array becomes indistinguishable from a healthy empty result, and you'll be debugging a "data missing" bug for hours.

```js
// WRONG — swallows failures, returns empty rows
const [a, b, c] = await Promise.all([
  fetchA().catch(() => []),
  fetchB().catch(() => []),
  fetchC().catch(() => []),
]);

// CORRECT — surfaces every failure
const SOURCES = ["a", "b", "c"];
const results = await Promise.allSettled([fetchA(), fetchB(), fetchC()]);
const data = results.map((r) => (r.status === "fulfilled" ? r.value : []));
const errors = results
  .map((r, i) => (r.status === "rejected"
    ? { source: SOURCES[i], error: r.reason.message }
    : null))
  .filter(Boolean);
return { data, _diagnostic: errors.length ? { errors } : undefined };
```

## 2. Never return placeholder state without a follow-up

No `{ generating: true, data: null }` from a cache miss. Pick one:

- **Generate synchronously** on miss (slow first request, fast subsequent), OR
- **Queue + return job ID + polling URL** (fast response, async resolution)

A placeholder with no follow-up creates a dead state — the UI shows "generating…" forever and the user has no recovery path. This is the bug class where your support queue fills up with "it's stuck."

## 3. Registries must include every alias

Any `LOOKUP[id]` access or `.filter((id) => REGISTRY[id])` is a **silent filter**. When you add a registry entry, include ALL forms the ID could appear in: snake_case, camelCase, hyphenated, kebab-case. Add a unit test that asserts every input ID maps to a known entry, and surface unknown IDs as `_diagnostic.warnings[]` rather than silently dropping them.

```js
// WRONG — silently drops "call_tracking" because the registry only has "calltracking"
const enabled = sourceIds.filter((id) => HANDLERS[id]);

// CORRECT — surface unknown ids loudly
const enabled = [];
const unknown = [];
for (const id of sourceIds) {
  if (HANDLERS[id]) enabled.push(id);
  else unknown.push(id);
}
if (unknown.length) {
  diagnostic.warnings.push({ msg: "unknown source ids", ids: unknown });
}
```

The registry-alias bug is especially nasty because it looks like a "user error" (wrong ID) when it's really a maintenance-drift bug (registry got out of sync with callers). Surface it; don't silently drop.

## 4. Every aggregating endpoint surfaces `_diagnostic`

If a route aggregates multiple sub-fetches (multi-source reports, dashboards, opportunity feeds, anything that fans out to N data sources), it MUST return a `_diagnostic` field at the response root when any sub-fetch fails or returns suspiciously empty:

```js
{
  success: true,
  data: { ... },
  _diagnostic: {
    errors:   [{ source: "analytics", error: "403 Property access denied" }],
    warnings: [{ source: "ads", note: "0 conversions in date range" }]
  }
}
```

Failures become visible via a plain `curl` — no log-tailing, no production debugging session needed. The cascading benefit is huge: the first time I added `_diagnostic` to a single aggregating route, I surfaced 5+ other sub-source bugs that had been silent for weeks. The convention pays for itself on day one.

## Adoption

If you're adopting this rule in an existing codebase, the order that worked for me:

1. **Rule 4 first** — add `_diagnostic` to your highest-traffic aggregating endpoint. You'll discover bugs that were already shipping. Fix them.
2. **Rule 1 next** — grep for `.catch(() => [])` and `.catch(() => null)` across the codebase. Replace each with `allSettled` + diagnostic. ~30 minutes of work, huge payoff.
3. **Rule 3 next** — find your largest registry or lookup table, add the "unknown IDs surface as warnings" pattern.
4. **Rule 2 last** — this one is about new code discipline, less about retrofit. Stop shipping placeholder-without-follow-up going forward.

## Related

- **Rule 4 + a shape-assertion test per route** is the minimum floor that catches "200 OK with empty payload" bugs. If the test asserts `data.items[0]` has expected shape AND the route surfaces `_diagnostic`, silent-empty is very hard to hide.
- When Claude is writing code that fans out to multiple sub-sources, instruct it explicitly: "Apply the loud-failures rule. Use `allSettled` not `Promise.all`. Return `_diagnostic` on partial failure."
