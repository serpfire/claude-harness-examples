---
name: handoff
description: Cash out a long Claude Code session before it runs out of context. Generates a structured state summary, copies it to your clipboard, and instructs you to /clear and paste it into a fresh session.
type: skill
---

# handoff — Session Handoff for Context Discipline

Save the useful state of a long Claude Code conversation before it runs out of context. Claude generates a structured summary from conversation memory (no file re-reads), copies it to your clipboard, and you paste it as the first message of a clean session. Zero context wasted, full continuity preserved.

This is a template — adapt the clipboard command and any project-specific sections to match your stack.

## Why this pattern matters

Context is an attention economy. Every token spent on a stale conversation is a token not available for reasoning on the work in front of you. The advanced move is knowing when to start a new session **before** the current one forces you to.

Rule of thumb: run `/handoff` at **50% context used, not 80%.** Cashing out early keeps the handoff summary lean and the fresh session's attention undiluted.

Typical savings: ~90%+ token reduction vs. letting a session run until auto-compaction kicks in. The handoff itself is ~400–600 words; a bloated session can be 200K+ tokens.

## When to fire it

- **Task boundary:** feature/fix/refactor is complete. Don't start the next task in the same context.
- **Phase boundary:** a multi-phase plan finishes a phase.
- **Research-heavy turn:** Claude read >5 files or >1,000 lines — context is now bloated.
- **"Summarizing earlier work to stay oriented":** if Claude is restating prior decisions to keep its own footing, you've already lost the efficient window.

## Installation

Save this file to `~/.claude/commands/handoff.md` (user-global — available in every project) or `<repo>/.claude/commands/handoff.md` (project-scoped). Invoke with `/handoff`.

## The skill

```markdown
---
description: Generate a context handoff summary, copy to clipboard, and prompt user to /clear and paste into fresh conversation
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
---

# Context Handoff

Generate a structured handoff summary of the current conversation, copy it to the clipboard, and instruct the user to start a clean session.

## Instructions

### Step 1: Gather State

Collect the following from your conversation context (do NOT re-read files or run commands — use what you already know from this session):

1. **Session Goal** — What the user asked you to do this session
2. **Work Completed** — Bullet list of what was accomplished (files created/modified, features built, bugs fixed, decisions made)
3. **Key Decisions** — Any architectural or design decisions with their rationale
4. **Pending Work** — Anything discussed but not yet done, or next steps identified
5. **Active Files** — Files that were being edited or are relevant to continue
6. **Current State** — Is the code working? Are there failing tests? Is anything deployed? What git branch?
7. **Blockers** — Anything stuck or needing resolution
8. **Mental Context** — The approach being taken, the "vibe" of the session, what the next move should be

### Step 2: Get Timestamp and Git State

```bash
echo "$(date '+%Y-%m-%d %I:%M %p %Z')"
```

Also check for uncommitted changes:
```bash
git status --short 2>/dev/null | head -20
```

### Step 3: Format the Handoff

Generate the handoff as a single markdown block. Use XML-style sections for clear parsing by the receiving Claude session:

```markdown
## Context Handoff — [DATE TIME from Step 2]

<session_goal>
[1-2 sentences describing what this session was about]
</session_goal>

<completed_work>
- [bullet points of completed work with specific file paths]
- [include what was built, fixed, or decided]
</completed_work>

<decisions_made>
- [decision]: [rationale]
- Chose [approach] over [alternative] because [reason]
</decisions_made>

<remaining_work>
- [ ] [uncompleted items or next steps, as a checklist]
- [ ] [be specific about what's left]
</remaining_work>

<active_files>
- `path/to/file.js` — [what was being done, current state]
- `path/to/other.js` — [context]
</active_files>

<current_state>
- Code status: [working/broken/partially working]
- Git branch: [branch name]
- Uncommitted changes: [yes/no, what]
- Deployed: [yes/no, where]
</current_state>

<blockers>
- [Blocker]: [status/workaround]
</blockers>

<next_action>
Start with: [specific first action when resuming — be concrete enough that a fresh Claude can pick up immediately]
</next_action>
```

### Step 4: Copy to Clipboard

Use a heredoc to safely handle the markdown content with special characters.

**macOS:**
```bash
cat <<'HANDOFF' | pbcopy
[paste the complete formatted handoff here]
HANDOFF
```

**Linux (X11):**
```bash
cat <<'HANDOFF' | xclip -selection clipboard
[paste the complete formatted handoff here]
HANDOFF
```

**Linux (Wayland):**
```bash
cat <<'HANDOFF' | wl-copy
[paste the complete formatted handoff here]
HANDOFF
```

**Windows (WSL):**
```bash
cat <<'HANDOFF' | clip.exe
[paste the complete formatted handoff here]
HANDOFF
```

### Step 5: Instruct the User

Display the handoff summary in the conversation so the user can review it, then tell them:

> **Handoff copied to clipboard.** To start fresh:
> 1. Type `/clear` to reset this conversation
> 2. Paste the handoff as your first message
> 3. Add any new instructions after the pasted context
>
> The new session will have full context of where you left off with a clean context window.

## Rules

- Do NOT ask the user questions — just generate the best summary you can from conversation context
- Keep the summary concise (under 600 words) — it needs to fit comfortably as a single prompt
- Focus on actionable state, not narration of what happened chronologically
- Include specific file paths (absolute paths preferred)
- If a plan or multi-step task is in progress, include current step / progress indicator
- Omit empty sections (e.g., if no blockers, skip `<blockers>`)
- The `<next_action>` section is the most important — make it specific enough that a fresh Claude instance can start working immediately without asking clarifying questions
```

## Design notes

**Why XML-style tags?** The receiving Claude session parses structured sections more reliably than flat prose. `<next_action>…</next_action>` is unambiguous; "what to do next" in paragraph form isn't.

**Why "no re-reads" in Step 1?** The whole point of the handoff is to cash out *what's already in context* — if Claude re-reads files to generate the summary, you're paying for the same bytes twice. Trust the conversation memory.

**Why under 600 words?** The handoff becomes the first message of a new session. A 5,000-word summary just moves the bloat from the old session to the new one. The discipline of fitting useful state in 600 words forces ruthless prioritization — and ruthless prioritization is what makes the handoff actually useful.

**Why `<next_action>` is the most important field?** A fresh Claude session reading the handoff needs one thing above all else: "what do I do first?" If `<next_action>` is specific enough ("Run `npm test` in `api/`, the failing test is `users.test.js:42`, the bug is in `lib/auth.js:88`"), the new session starts instantly. If it's vague ("continue the refactor"), the new session wastes tokens asking clarifying questions — defeating the whole point.

## Sibling pattern: one-shot handoff

If you want a quicker variant that skips some of the structured sections (useful mid-task instead of at a clean boundary), create `handoff-one.md` with a stripped-down version of the same skill — same clipboard copy, same `/clear` workflow, just fewer sections.

## Related rules

This skill pairs with a context-discipline rule that defines *when* `/handoff` should fire — task boundaries, phase boundaries, research-heavy turns. The skill itself is reactive (you invoke it); the rule is proactive (it tells Claude to invoke it). Consider adding a `context-discipline.md` rule to your harness that lists the fire conditions above.
