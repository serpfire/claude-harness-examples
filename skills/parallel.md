---
name: parallel
description: Dispatch work as parallel subagents in a single message, with sandboxed data gathering inside each agent and tight word-capped output contracts. Prevents the three most common Claude Code overspend patterns.
type: skill
---

# parallel — Parallel + Token-Efficient Work

Default working pattern for research, data gathering, and any task that can split into independent slices.

**The problem this solves:** the three most expensive mistakes new Claude Code users make are (1) dispatching sub-agents sequentially when they could run in parallel, (2) pulling raw tool output back into the parent context, and (3) spawning a full sub-agent for pure data-gathering tasks that a sandboxed script would handle in one call. Each of those wastes minutes and thousands of tokens. This skill replaces all three with one discipline.

## Installation

Save this file to `~/.claude/commands/parallel.md` (user-global) or `<repo>/.claude/commands/parallel.md` (project-scoped). Invoke with `/parallel <task description>`.

The skill ships with a companion rule (below) that encodes the same pattern as default behavior — so the discipline applies even when you don't type the slash command.

## The pattern

1. **Parallel dispatch** — if the work splits into N independent slices, send ONE message with N Agent tool calls. Never sequentially dispatch agents that don't depend on each other. "Run agent A, wait, run agent B, wait, run agent C" burns wall-clock for no reason when they could all run at once.

2. **Sandbox data gathering inside each subagent** — each subagent prompt must instruct the agent to keep raw bytes inside a sandboxed execution environment, not in the subagent's context. The goal: logs, query results, and large file reads stay out of the subagent's context window entirely. Only summaries leave the sandbox. (See "Sandbox tooling" below for implementation options.)

3. **Tight output contracts** — every subagent prompt ends with a word cap: *"Report under 150 words, file paths + findings only. No raw data dumps."* Without this cap, subagents return essays. With it, they return actionable synthesis.

4. **Synthesis at the parent** — parent reads only short summaries. Never pull raw logs / full query output back to the parent. If you need the raw data, the subagent is the wrong layer.

5. **Pick the cheapest agent type that fits** — Explore-style or Haiku for grep/find; Sonnet for reasoning; Opus only when deep architecture work is required. The default assumption "bigger model = better output" is usually wrong for mechanical work.

## Single-thread decision

When parallelization isn't possible, still make the right call:

| Bottleneck | Use |
|---|---|
| Data volume (logs, query results, many files to filter) | **Sandbox execution only** — no subagent, just run the script, keep output in the sandbox, return a summary |
| Reasoning (open-ended research, architecture) | **Single subagent** |
| Both | **Single subagent** instructed to use sandbox execution internally for data gathering |

## Anti-patterns (blocked)

- **Dispatching 3+ subagents sequentially when they're independent.** Costs wall-clock for nothing. If the second agent doesn't depend on the first's output, fire both in one message.
- **Subagents that return raw logs / full query results to parent.** Pays subagent overhead AND floods parent context. Worst of both worlds.
- **Using `Read` or `Bash` in the parent to pull large output into context** when sandbox execution would keep it out. The parent context is precious; never fill it with bytes you could have summarized.
- **Spawning a subagent for a task that's pure data-gathering with no reasoning** — sandbox execution alone is cheaper.
- **Using sandbox execution for reasoning-heavy work** that a subagent would handle in one pass.

## Enforcement cue

Before any Agent tool call or multi-step data-gathering work, ask: *"can this split into independent slices?"*

- **Yes** → parallel Agent calls, one message, sandbox execution inside each, word cap in every prompt.
- **No** → pick sandbox-only OR single subagent by the table above.

## Sandbox tooling

This skill is tool-agnostic about where the raw bytes actually go — it just requires that raw bytes stay out of the subagent's context. Two common implementations:

**Option A — context-mode MCP plugin** *(recommended if you use it)*
The context-mode plugin provides `ctx_batch_execute`, `ctx_search`, `ctx_execute`, and `ctx_execute_file` — which run commands in a subprocess, index the output, and return only the sections you searched for. This is the sharpest implementation of the pattern. If you have it installed, reference these tools by name in your subagent prompts: *"Use `ctx_batch_execute` for data gathering. Keep raw output in the sandbox."*

**Option B — plain script output with explicit summary**
If you don't use context-mode, the subagent prompt should include: *"When running shell commands or reading files that produce more than ~50 lines, write the output to a temp file and only include a summary in your reply. Do not paste raw output into your response."* Less automated than Option A, but achieves the same goal.

Either way, the parent never sees raw bytes. That's the invariant.

## The skill (for `~/.claude/commands/parallel.md`)

```markdown
---
description: Dispatch the task as parallel subagents, each using sandboxed data gathering, with tight output contracts
---

# /parallel

Activate the parallel + token-efficient working pattern for this task.

## Steps

1. **Analyze the task.** Can it split into N independent slices (by file tree, service, data source, question)? If no, fall through to the single-thread table and pick sandbox-only OR single subagent accordingly.

2. **If parallelizable:** dispatch N subagents in a SINGLE message with multiple Agent tool calls. Do not dispatch sequentially.

3. **Each subagent prompt MUST include:**
   - A self-contained briefing (goal, relevant paths, what's already known, what to return).
   - Explicit instruction to keep raw data in a sandbox — either a specific sandboxed-execution tool (e.g., context-mode's `ctx_*` tools) or "write to temp file, summarize in reply."
   - A word cap: "Report under 150 words. File paths + findings only. No raw data dumps."
   - The right agent type — Explore or Haiku for grep/find; Sonnet for reasoning; Opus only for deep architecture.

4. **Synthesis at the parent.** Read the short summaries. Do not pull raw data into parent context at any step.

5. **Report back** with the synthesized answer, citing file paths and findings — not raw content.

## Arguments

$ARGUMENTS — the task to parallelize. If empty, ask the user what to split.
```

## The companion rule (for `<repo>/.claude/rules/parallel-token-efficient.md`)

Write this as a mandatory rule in your `CLAUDE.md` so the baseline pattern applies even without `/parallel`:

```markdown
# Parallel & Token-Efficient Work

Default working pattern for research, data gathering, and any task that can split into independent slices.

[...copy the "The pattern" and "Anti-patterns" sections above...]

Invocation: /parallel <task> explicitly activates this pattern. Baseline behavior applies even without the slash command — see the Enforcement cue above.
```

## Why this matters

Without this discipline, a single "audit the codebase for X" task can cost:
- **Sequential subagents:** 3 subagents × 30 seconds each = 90 seconds of wall-clock and 3× model overhead
- **Raw output leakage:** 50,000 tokens of grep results flooding the parent context, pushing useful discussion out of the window
- **Wrong agent for the job:** Opus Sonnet for a grep task that Haiku or Explore would handle for 1/10th the cost

With the discipline:
- **Parallel dispatch:** 3 subagents × 30 seconds = 30 seconds wall-clock
- **Sandboxed execution:** ~200 tokens summary per agent, 600 tokens total into parent
- **Right-sized model:** Haiku or Explore for mechanical work, Sonnet only for synthesis

**Typical savings: 10×+ on wall-clock and 50×+ on tokens** for research-heavy tasks. This compounds over a working day — the difference between a harness that feels fast and one that feels expensive.
