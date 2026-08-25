---
name: finish-worktree
description: Finish up all work in the current git worktree — commit, rebase onto main, land on main (fast-forward, or merge if asked), then remove the worktree and delete its branch. Use when the user wants to wrap up, land, ship, or finish the work in this worktree and clean it up.
---

# Finish Worktree

Land the current session's worktree work onto `main` and clean up, with no work lost.
Commit outstanding changes, rebase the task branch onto `main`, fast-forward it into
`main` from the primary worktree, then remove this worktree and delete the branch.

This follows the repo's worktree fan-out convention: `main` lives alone in the primary
worktree and is only ever an integration point; task branches rebase then land with
`--ff-only`. A branch checked out in a worktree is locked, so `main` is always updated
**from the primary worktree**, never from inside the task worktree.

## Safety principles

- **Never lose work.** Everything is committed and landed on `main` before anything is removed.
- **Fast-forward by default.** Land with `git merge --ff-only` so a surprise merge commit
  never appears. Only create a merge commit if the user explicitly asks to merge.
- **Stop on conflicts.** If a rebase conflicts, hand it back to the user — never force.
- **Confirm before landing unrelated commits.** If the branch carries commits you didn't
  make this session, show them and confirm before landing.
- **Only remove this worktree.** Never remove the primary/main worktree. If somehow run
  from the primary worktree, stop — there is nothing to finish.

## Procedure

### 1. Establish the three facts you need

```bash
# The worktree you're in and its branch
git rev-parse --show-toplevel
git branch --show-current

# All worktrees — identify the PRIMARY (the one on `main`)
git worktree list
```

- `CURRENT` = the worktree from `--show-toplevel`.
- `BRANCH`  = the current branch.
- `PRIMARY` = the worktree checked out on `main` (usually `~/Desktop/solid-groove`).

If `CURRENT` is `PRIMARY` (you're on `main` in the primary worktree), stop: this skill
finishes a *task* worktree, and there is nothing to land or remove. Tell the user.

### 2. Commit outstanding changes

```bash
git -C <CURRENT> status --porcelain
```

If there is any output, commit it (invoke the user's `commit` skill if available, or
write a clear message summarizing the changes; first line ≤ ~50 chars, add a body if the
diff is more than ~30 lines). End the commit message with the project's required trailer:

```
Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>
```

If the working tree is already clean, continue.

### 3. Check what will land

```bash
git log --oneline main..<BRANCH>    # commits that will move onto main
```

- Empty → the branch is already on `main`; skip to step 6 (just clean up).
- Commits you made this session → proceed.
- Unexpected commits → show them (`git show --stat <commit>`) and confirm with the user
  before landing.

### 4. Rebase the task branch onto main

Keeps history linear and resolves conflicts inside the task worktree, not on `main`:

```bash
git -C <CURRENT> rebase main
```

If the rebase conflicts, **stop** and hand it back to the user with the conflicting files.
Do not force or abort without asking.

### 5. Land on main from the primary worktree

Fast-forward only — this is why the branch was just rebased:

```bash
git -C <PRIMARY> merge --ff-only <BRANCH>
```

- If it refuses (`main` moved since the rebase), repeat step 4 then retry step 5.
- **Only if the user explicitly asked to merge** (not fast-forward) may you instead run
  `git -C <PRIMARY> merge --no-ff <BRANCH>` to create a merge commit.

### 6. Remove the worktree and delete the branch

Drive removal from the primary worktree so you're not deleting the tree you stand in
via a relative path:

```bash
git -C <PRIMARY> worktree remove <CURRENT>
git -C <PRIMARY> branch -d <BRANCH>
```

`branch -d` refuses an unmerged branch as a safety net. If it refuses even though the
commits are truly on `main`, verify with
`git merge-base --is-ancestor <BRANCH> main && echo on-main` before using `-D`
(this happens when the branch is ahead of its `origin/...` tracking ref but still merged
into `main`).

### 7. Report

Confirm: what was committed, that the branch landed on `main` (fast-forward or merge),
and that the worktree and branch were removed. Show the final `git worktree list`.

## With a remote and pull requests

If the project integrates via PRs rather than local landing, don't touch local `main`.
Instead: commit, push the branch, open/complete the PR, then
`git -C <PRIMARY> pull --ff-only` and clean up with step 6. Ask the user which flow they
want if it's unclear; local `--ff-only` landing is the default for this project.

## Decision summary

| Situation | Action |
|---|---|
| Uncommitted changes | Commit them (step 2) |
| Branch already on main | Skip landing; just clean up (step 6) |
| Unexpected commits on branch | Show and confirm before landing |
| Rebase conflict | Stop; hand back to user |
| `--ff-only` refused | Re-rebase onto moved main, retry |
| User asked to merge, not ff | `merge --no-ff` instead of `--ff-only` |
| Run from primary/main worktree | Stop; nothing to finish |
