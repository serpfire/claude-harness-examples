# Grep Before You Edit

Before modifying ANY code to fix a bug, apply a pattern, or change behavior:

1. **Grep the entire codebase** for all occurrences of the pattern, function, variable, or logic you're about to change.
2. **List every file and line** that needs the same fix.
3. **Apply the fix to ALL locations in one pass** — never fix one file and wait for the user to report the next.

Not optional. Do not touch a single file until you know the full scope. One grep upfront prevents five rounds of "you missed this one too."

**Applies to:** bug fixes, refactors, renamed variables, new patterns replacing old ones, entity-type corrections, demo masking, URL parameter changes — anything that could exist in more than one place.

## Scope-creep ≠ full-fix (critical clarification)

The general "don't add features beyond what the task requires" principle refers to **UNRELATED features** — helpers, abstractions, hypothetical future requirements. It does NOT give license to fix only one manifestation of the bug you were asked to fix.

**Every read path, write path, cache path, and export path that surfaces the same root cause IS in scope of the original bug report.** Shipping a fix that repairs the screen the user happened to be looking at while leaving a sibling endpoint broken is a partial fix, not a completed one. The user will find the sibling bug within hours, and the "don't add scope" framing will have cost two round-trips instead of saving one.

### Forbidden framings

Do NOT say, write in commit messages, or silently act on:

- *"Scope creep risk — leaving X for a separate pass"* (when X is the same bug)
- *"Keep the fix focused on the surface the user mentioned"* (when other surfaces share the root cause)
- *"Out of scope for this task"* (when it's a manifestation of the task's root cause)

These phrases are the rationalization, not the rule. If you find yourself typing one of them while debugging, **STOP** and re-map the full problem surface with the additional context included. That "I should also handle X" thought mid-implementation is the signal that the original scope mapping missed something.

### Litmus test

Before declaring a bug fix done, answer in one sentence:

> "If the user re-runs the exact query that surfaced this bug, on a different but equivalent input, via a different but equivalent endpoint, does my fix still hold?"

If no, the fix is not done. Expand scope until yes — that's not creep, that's the job.

### Scope vs. creep — worked examples

| The task | In scope (MUST fix) | Out of scope (creep) |
|---|---|---|
| "export PDF is failing with validator error at blocks[30]" | all callers of the function emitting the bad block; the editor GET path that renders the same IR; any other exporter sharing the adapter | rewriting the adapter architecture; adding a new block type; refactoring the validator |
| "editor shows stale lead numbers" | every read path that loads a snapshot (editor GET, export POST, public share page); every code path that writes the snapshot if the bug is write-side | adding a new snapshot UI; restructuring the freshness-cache tier |
| "nav button highlights wrong item" | every sidebar entry + route using the same highlight matcher; the active-state logic itself if shared | redesigning the sidebar; renaming unrelated entries |
| "model ID X is stale" | every hardcoded reference to X + shared constants; tests asserting the old ID | migrating off the wrapper pattern; rewriting the LLM library |

When in doubt, the question is NOT "is this more than the user asked for?" — it's **"does this share a root cause with what the user asked about?"** If yes, fix it.

## How to enforce this with Claude

Put it in your `CLAUDE.md` as an `@`-imported rule, so every session loads it:

```markdown
@.claude/rules/grep-before-edit.md
```

Then, when you find Claude fixing one location and leaving a sibling broken, point at this rule and say "re-read grep-before-edit, then try again." The rule becomes a shared vocabulary — you and Claude both know what "grep the full scope" means without re-explaining.

## Pair with: a pre-edit hook (optional but powerful)

You can automate the enforcement. A `PreToolUse` hook on the `Edit` tool can:

1. Extract the identifier being changed.
2. Run `grep -rn "<identifier>" <project-root>` and count occurrences.
3. If occurrences > 1, print the list and block/prompt before allowing the edit.

This is the approach behind `hooks/grep-related-occurrences.sh` in this repo — the rule teaches the discipline; the hook enforces it when muscle memory fails.
