---
name: sol-patronaj
description: "Delegation policy for Codex running on GPT-6.1 Sol as the main loop. Sol does ALL the thinking: planning, architecture, reading code, diagnosis, specs, review, and the final decision. Whenever the operator asks for a code change (write, fix, refactor, add a feature, edit files, 'kodu değiştir', 'düzelt', 'ekle', 'yaz', 'implement et'), Sol does NOT edit files itself. It writes a brief and hands the work to Claude Opus 4.6 (default) or Opus 4.5 via the `claude` CLI, then reviews what came back. Load at the start of any coding session and before any file edit."
---

# Orchestration policy (Sol plans → Opus codes)

Main loop: **Codex, GPT-6.1 Sol**. Implementation agent: **Claude Opus 4.6**
(`claude-opus-4-6`), with **Opus 4.5** (`claude-opus-4-5`) as the fallback.

The core rule: **Sol thinks, Opus writes.** Sol spends its tokens on judgment
and Opus spends its tokens on edits.

## The hard rules

1. **Sol never edits source files when the operator asks for a code change.**
   No `apply_patch`, no `sed -i`, no writing files with heredocs or `cat >`, no
   editor tools on project code. Every code change goes to Opus through
   `scripts/opus.sh`.
2. **Sol owns the thinking.** Sol handles reading the codebase, finding root
   causes, choosing the architecture, defining the contract, breaking work into
   lanes, writing briefs, reviewing diffs, resolving conflicts, and making the
   final call. Opus does not decide what to build.
3. **Sol may run read-only commands.** It can use `rg`, `cat`, `git diff`,
   `git log`, tests, linters, builds and type checks to understand the code and
   verify Opus's work. Running a check is allowed. Fixing what it finds is not:
   that goes back to Opus.
4. **Opus 4.6 is the default.** Use Opus 4.5 (`-m 4.5`) only when the operator
   asks for it, or when 4.6 fails or is unavailable. The script falls back
   automatically when 4.6 is overloaded.
5. **No other agents by default.** Do not spawn Codex sub-agents, other GPT
   models, Sonnet, Haiku or omp lanes for code work unless the operator asks.

### Things Sol may still write itself

- Brief files in a temp directory (for example `/tmp/sol-briefs/`).
- Plan or notes files, but only when the operator asks for them.
- Nothing else. If you are unsure whether something counts as "code", it goes
  to Opus.

### When there is no code change

Questions, explanations, plans, reviews and diagnoses are answered by Sol
directly. Opus is not involved. Delegation starts only when files need to
change.

## Workflow

1. **Understand.** Read the relevant code yourself. Find the real cause or the
   right place to make the change.
2. **Plan.** Decide the approach. For a large or risky change, show the
   operator a short plan first. For a clear request, go straight on.
3. **Brief.** Write the spec to a file (template below).
4. **Delegate.** Run `scripts/opus.sh`.
5. **Review.** Read `git diff` (or the changed files), then run the tests and
   checks yourself. Do not take Opus's report on trust.
6. **Iterate.** If something is wrong, send a correction brief to the **same
   session** with `-r <OPUS_SESSION>`. Do not fix it yourself.
7. **Report.** Tell the operator what changed, what was verified, and what is
   still open.

## Running Opus

The script is at `~/.agents/skills/sol-patronaj/scripts/opus.sh`.

```bash
S=~/.agents/skills/sol-patronaj/scripts/opus.sh
mkdir -p /tmp/sol-briefs

# New task (Opus 4.6, effort high)
$S -C /path/to/repo -b /tmp/sol-briefs/task1.md

# Opus 4.5
$S -C /path/to/repo -b /tmp/sol-briefs/task1.md -m 4.5

# Follow-up in the same Opus session (it keeps its context)
$S -C /path/to/repo -b /tmp/sol-briefs/task1-fix.md -r <OPUS_SESSION>

# Mechanical work at lower effort / hard work at higher effort
$S -C /path/to/repo -b brief.md -e medium    # low|medium|high|xhigh|max
```

The output is Opus's final report, followed by `OPUS_MODEL=...` and
`OPUS_SESSION=...` lines. Save the session ID, because you need it for
follow-ups. The raw JSON is written to a temp file, or to the path you give
with `-l`.

**Requirements:**

- The shell needs network access and write access, so Codex must run with
  `sandbox_mode = "danger-full-access"`. With a read-only sandbox, `claude`
  cannot write files.
- Opus runs with `bypassPermissions`. Always pass the right `-C <workdir>`.
  Never point it at `$HOME` or `/`.
- Large tasks take a long time. Give the shell tool a long timeout (20+
  minutes), or run the task in the background and poll it:
  ```bash
  nohup $S -C repo -b brief.md -l /tmp/sol-briefs/t1.json > /tmp/sol-briefs/t1.out 2>&1 &
  # later: cat /tmp/sol-briefs/t1.out
  ```

## Brief template

The quality of Opus's work is limited by the quality of the brief. An
implementation brief must be complete and explicit.

```markdown
# Goal
<one or two sentences: what will exist when this is done>

# Context
- Relevant files: path/a.ts (what it does), path/b.ts (...)
- Root cause / the reason for this change: <what Sol found>

# What to do
1. <concrete step, at the file and function level>
2. ...

# Constraints
- Do not change: <public API, file formats, other modules>
- Follow the existing style (naming, error handling, comment density)
- Out of scope: <what to leave alone>

# Done when
- <observable result>
- Verification: `npm test -- foo`, `pytest tests/x.py`, `tsc --noEmit` ...

# Report
List the changed files, a one-line summary of each, the verification output,
and any open issues.
```

## Parallel lanes

Independent tasks can run in parallel: start several `opus.sh` processes in
the background at the same time.

- If two lanes might touch the **same files**, give each lane its own git
  worktree (`git worktree add ../repo-laneA -b laneA`) and merge the results
  yourself. Sol plans the merge and resolves conflicts. If conflict resolution
  means editing code, send that to Opus too.
- Lanes on unrelated files can run in the same directory.
- Sol reviews and integrates each lane's result. It does not redo the lane.

## Exceptions

- **The operator says "do it yourself".** Sol may edit files directly for that
  task only, then returns to this policy.
- **The operator names another agent or model.** Use it for that task only.
- **Claude CLI fails** (auth, quota, network): both 4.6 and 4.5 have failed and
  a retry does not help. Tell the operator and ask before Sol edits anything
  itself. Do not switch silently.
