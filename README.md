# claude-harness-examples

Hand-picked artifacts from Noah Learner's Claude Code harness, shared alongside the SEO Week NYC 2026 talk **"Scars."**

Every file here started as something that cost me. A scar became a rule; the rule became a hook or a skill or a verb. This repo is the curated starter kit — the pieces most likely to help you the fastest. It is deliberately *not* my whole harness. Fewer, better, heavily commented.

---

## The five-layer model

Every file in this repo is one of five layers. Understand the layers and you can build your own:

- **Rules teach.** Plain text. Readable. Loaded into your Claude Code session at startup. A rule is what you've learned, written down so future-you (and Claude) can honor it. → [Claude Code memory docs](https://docs.claude.com/en/docs/claude-code/memory)
- **Hooks enforce.** Code. Automatic. Fires before you can do the wrong thing. A hook is the discipline you don't trust yourself to remember at 11 PM. → [Claude Code hooks guide](https://docs.claude.com/en/docs/claude-code/hooks-guide) · [hooks reference](https://docs.claude.com/en/docs/claude-code/hooks)
- **Skills automate.** Named workflows. Playbooks you got tired of re-explaining. Invoked with a slash command. → [Claude Code skills docs](https://docs.claude.com/en/docs/claude-code/skills)
- **Agents delegate.** Parallel workers you dispatch for independent slices. Raw data stays in the sub-agent's context, not yours. → [Claude Code sub-agents docs](https://docs.claude.com/en/docs/claude-code/sub-agents)
- **Verbs command.** Operating modes. One word activates a whole discipline. A verb is a gate you've chosen to run through. → [Claude Code slash commands](https://docs.claude.com/en/docs/claude-code/slash-commands)

Together they build a version of you that can't cut corners.

## The promotion loop

You don't build the whole harness on day one. You **promote** one artifact at a time:

```
SCAR  ─▶  RULE  ─▶  HOOK  ─▶  SKILL/AGENT  ─▶  VERB
       (write it  (keep breaking (procedure    (mode you
       down)       the rule)      repeats)     flip into)
```

Every new Claude model release, re-audit which layer each thing belongs in. Things that were rules become hooks. Skills become agents. That's the engine.

## Severity tiers

Not all work deserves the same rules. Tag tasks as one of three tiers before you start:

- **Trivial** — typos, one-line fixes, mechanical changes. Minimum ceremony.
- **Standard** — contained feature, 20–200 lines. Run the usual checks.
- **Heavy** — resilience, data flow, infrastructure, anything where "works most of the time" is unacceptable. Full rules, full strength.

Scaling rules to task size stops the harness from feeling like bureaucracy.

**Official Claude Code docs as a set:**
- [Overview](https://docs.claude.com/en/docs/claude-code/overview) — start here if you're new
- [Memory (CLAUDE.md)](https://docs.claude.com/en/docs/claude-code/memory) — where rules live
- [Hooks guide](https://docs.claude.com/en/docs/claude-code/hooks-guide) — concepts and use cases
- [Hooks reference](https://docs.claude.com/en/docs/claude-code/hooks) — JSON contract + events
- [Skills](https://docs.claude.com/en/docs/claude-code/skills) — SKILL.md format and invocation
- [Sub-agents](https://docs.claude.com/en/docs/claude-code/sub-agents) — delegation and parallel work
- [Slash commands](https://docs.claude.com/en/docs/claude-code/slash-commands) — how to wire verbs
- [Settings](https://docs.claude.com/en/docs/claude-code/settings) — permissions, env vars, precedence
- [Plugins reference](https://docs.claude.com/en/docs/claude-code/plugins-reference) — packaging the above as shareable plugins

---

## What's in this repo

### `hooks/` — two hooks, two scars

**[`database-query-guard.sh`](hooks/database-query-guard.sh)** — The $1,700 scar
- I wrote one BigQuery query, hit enter, and it cost $1,700. BigQuery charges per byte scanned, not per row returned. You can return 3 rows and scan 340 terabytes. I did.
- The hook now fires before Claude runs any database query on my machine. It dry-runs, calculates the cost at $5/TB, shows me the number, and asks. I decide every time.
- Works across 15 database systems (BigQuery, Athena, Snowflake, Postgres, MySQL, SQLite, MongoDB, Redis, DynamoDB, and more). Catches DELETE without WHERE, Redis FLUSHALL, Mongo collection drops — not just cost disasters.

**[`grep-related-occurrences.sh`](hooks/grep-related-occurrences.sh)** — The demo-leak scar
- I ran a live webinar with real client names visible on the screen. They leaked. I went home, built a masking mode, and then spent the next day finding every place in the code that rendered a client name. I missed four.
- The hook now fires before every edit. It greps for related occurrences of the pattern you're about to change and asks you to review them before proceeding.
- Grep-before-edit used to be a rule I had to remember. Now it's a gate I have to walk through.

### `rules/` — two rules that changed how I work

**[`noah-verbs.md`](rules/noah-verbs.md)** — Seven operating-mode verbs
- `noahloop` (decide), `noahplan` (plan deep, no code until confirmed), `noahship` (deploy gate), `noahcut` (dead-code pass), `noahbot` (delegate + handoff), `noahfix` (autonomous debug), `noahwatch` (live observation).
- Composable. Rename them. Keep the ones that fit. Invent your own. The value isn't in these specific seven — it's in the pattern: one word loads a whole discipline.

**[`done-means-done.md`](rules/done-means-done.md)** — The forcing function behind everything
- Two phases, before coding and before claiming done. Phase A makes you solve the problem right (not just minimally). Phase B is five checks that run before any "done" claim — with a hard gate that you exercise the feature like a user in the same message as the done claim, with concrete evidence (curl output, screenshot, query result).
- This rule fixed more bugs-on-arrival than any other change I made. Steal it wholesale.

**[`loud-failures.md`](rules/loud-failures.md)** — Four sub-rules that kill silent degradation
- No `Promise.all` with `.catch(() => [])`. Never return placeholder state without a follow-up. Registries must include every alias. Every aggregating endpoint surfaces `_diagnostic`.
- They share one root cause: *the system continued executing after partial failure without telling anyone.* One file, one rule to remember.
- The first time I added `_diagnostic` to a single aggregating route, I surfaced 5+ silent bugs that had been live for weeks. This rule pays for itself on day one.

**[`grep-before-edit.md`](rules/grep-before-edit.md)** — The scope-vs-creep rule
- Before modifying any pattern: grep the whole codebase, list every match, fix them all in one pass. Never fix one file and wait for the user to report the next.
- Includes the "scope vs. creep worked examples" table — the framework for distinguishing legitimate full-scope fixes from actual scope creep.
- Pairs with `hooks/grep-related-occurrences.sh` — the rule teaches the discipline; the hook enforces it when muscle memory fails.

### `skills/qa-explore-template.md` — autonomous visual QA

My highest-leverage skill. **Claude logs into my deployed app, navigates a workflow, takes screenshots, reads its own screenshots, inspects API responses, and reports findings. I do nothing.** Template version — swap in your auth helper, test config, and URL patterns.

- Before I ship any page, I run `/qa-explore /app/my-page`. Four minutes later I have a pass/fail verdict with evidence.
- The advanced discipline isn't automating the action. It's **automating the verification** — skills that read their own output.
- Apply this pattern to anything visual: reports, dashboards, client deliverables, onboarding flows.

### `skills/handoff.md` — cash out a long session at 80% left, not 50% or 20%

Context is an attention economy. Every token spent on a stale conversation is a token not available for the work. `/handoff` generates a structured summary of the current session from conversation memory (no file re-reads), copies it to the clipboard, and you paste it as the first message of a fresh session.

- Run it at **task boundaries, phase boundaries, and any time Claude is summarizing earlier work to stay oriented** — that's the signal the window is already bloated.
- Typical savings: ~90% token reduction vs. letting the session auto-compact.
- The `<next_action>` field is the most load-bearing part — make it specific enough that the fresh Claude session can start without clarifying questions.
- Clipboard commands included for macOS, Linux (X11/Wayland), and Windows (WSL).

### `skills/docs-update-template.md` — living docs from source code

Most in-app documentation is stale before it ships. Someone wrote it once, renamed a button, and the doc is now lying to your users. **This skill fixes the ongoing version of that problem: every time a feature changes, the doc regenerates from the current code.** Markdown content plus screenshots, both kept honest.

- Seven modes: `check`, `generate <slug>`, `generate-all` (parallel subagents), `update`, `update-all`, `screenshots`, `bootstrap <slug>`.
- Reads your view files + API routes + state, writes structured markdown, captures a screenshot via your test runner, optimizes to WebP at quality 80.
- Stack-agnostic template — works for Vue, React, Next.js, Svelte, any framework with "a view, a route, and a markdown destination."
- Pair with a `feature-registry` rule for the "every new view gets a doc entry" convention, or wire a `PostToolUse` hook for true on-change automation.
- This is the skill behind the `docs(auto):` sync commits — docs can't go stale because they're generated from the same source of truth as the UI.

### `skills/parallel.md` — parallel subagents + sandboxed data gathering

The three most expensive mistakes new Claude Code users make: (1) dispatching sub-agents sequentially when they could run in parallel, (2) pulling raw tool output back into the parent context, (3) spawning a full sub-agent for pure data-gathering tasks that a sandboxed script would handle in one call.

This skill replaces all three with one discipline:
- **One message, N agents.** Never serialize independent work.
- **Sandbox the raw data.** Every subagent prompt includes "keep raw bytes in the sandbox" — logs, query results, and large file reads never enter a context window.
- **Word-capped output contracts.** Every subagent prompt ends with "Report under 150 words. File paths + findings only. No raw data dumps."
- **Right-sized agents.** Haiku/Explore for grep; Sonnet for reasoning; Opus only for deep architecture.

Typical savings: 10×+ on wall-clock, 50×+ on tokens for research-heavy tasks.

### `skills/learned/` — two post-mortem skills

After a non-trivial debugging session, I extract the pattern into a skill file so Claude (and future-me) can recognize it next time. These two are the most universally useful.

**[`kv-rate-limiter-ttl-bug.md`](skills/learned/kv-rate-limiter-ttl-bug.md)** — Why your rate limiter locks users out forever
- The bug: `expirationTtl` resets the TTL from now on every write. Under active use, the key never expires. Users hit the limit and stay locked out until traffic stops for 60 seconds — which never happens.
- Applies to any KV store with TTL-based expiration (Cloudflare KV, Redis with `EXPIRE`, DynamoDB TTL).

**[`cloudflare-worker-response-body-leak.md`](skills/learned/cloudflare-worker-response-body-leak.md)** — The silent memory trap
- The bug: calling `fetch()` and not reading the body (or explicitly cancelling it) keeps the body in memory. Workers cap at 128MB. You'll hit it, and the error message ("A stalled HTTP response was canceled to prevent deadlock") won't tell you what's wrong.
- The fix is one line: `response.body?.cancel()` on every early-return path.
- Applies beyond Cloudflare — same trap exists in any runtime with streamed response bodies.

---

## Related public repos

These are separate projects I built while growing the harness. Fork freely:

- **[sterlingsky/claude-deploy-hook](https://github.com/sterlingsky/claude-deploy-hook)** — Multi-provider deploy hook covering 11 platforms (GCP, Firebase, Vercel, Cloudflare, K8s, AWS, Azure, Heroku, Fly.io, Render, Netlify).
- **[sterlingsky/claude-ship-command](https://github.com/sterlingsky/claude-ship-command)** — The `/ship` slash command that backs `noahship`.

---

## Install

### Hooks (user-global)
```bash
mkdir -p ~/.claude/hooks
cp hooks/*.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/*.sh
```
Then follow the install steps at the top of each hook to wire it into your Claude Code settings.

### Rules (project-local)
```bash
mkdir -p .claude/rules
cp rules/*.md .claude/rules/
```
Import in your `CLAUDE.md`:
```markdown
@.claude/rules/noah-verbs.md
@.claude/rules/done-means-done.md
```

### Skills — two flavors

**Invokable skills (slash commands like `/handoff` or `/qa-explore`)** live under `~/.claude/commands/`:
```bash
mkdir -p ~/.claude/commands
cp skills/handoff.md ~/.claude/commands/handoff.md
cp skills/qa-explore-template.md ~/.claude/commands/qa-explore.md
```
Invoke with `/handoff`, `/qa-explore`, etc. Can also live project-local at `<repo>/.claude/commands/`.

**Pattern skills (contextual knowledge, not commands)** live under `~/.claude/skills/`:
```bash
mkdir -p ~/.claude/skills/learned
cp skills/learned/*.md ~/.claude/skills/learned/
```
These describe *patterns* — Claude reads them as context when a matching situation arises. Not invoked directly.

---

## Three things to do tonight

If you only take away three moves from this repo:

1. **Install `database-query-guard.sh`.** Five minutes. Saves a disaster.
2. **Copy `noah-verbs.md`, rename the verbs to fit your workflow**, and start using one.
3. **When a bug bites you twice, write a rule within the hour.** The rules in this repo all started that way.

That's the whole starter kit. Everything else compounds from those three moves.

---

## License

MIT. Fork, modify, share. If something here helps, reach out — I'd love to hear about it.

---

## About the talk

This repo drops alongside **"Scars"** at SEO Week NYC, April 27, 2026. The talk is about turning scars into infrastructure. This repo is the infrastructure. If a QR code in the deck brought you here, welcome — take what's useful.
