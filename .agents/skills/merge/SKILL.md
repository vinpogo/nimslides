---
name: merge
description: >-
  Merge a change into local main of the nimslides repository
  (/home/vin/projects/nimslides) by rebasing and fast-forwarding, after
  nimble test, nimble build and nph pass. Only invoke when the user has
  explicitly requested merging or landing a change, not for review,
  preparation, running checks, or skill installation.
disable-model-invocation: true
metadata:
  delta-action: land
---

# Merge a change into nimslides `main`

Applies only to the nimslides repository at `/home/vin/projects/nimslides`.

Invoking this skill (including via `/merge`) **is** the explicit merge request.
Do not ask whether the user wants to merge and do not reply that you are
waiting for an explicit merge request. Run the workflow below. Stop only for
real blockers: failing or unrunnable checks, unclear scope, conflicts whose
intent is ambiguous, or unrelated work that would be overwritten.

## Destination and policy

- Target: **local `main`** in `/home/vin/projects/nimslides`. **Never push.**
  The repository has no CI and no pull-request flow, and `main` is kept local
  (it is ahead of `origin/main` on purpose).
- History is linear: rebase the change onto `main`, then fast-forward. Never
  create merge commits (`git config pull.rebase` is `true`, and `git log` is linear).
- Commit messages use Conventional Commits in the existing style, e.g.
  `feat: strikethrough`, `chore: add .claude to gitignore`: lowercase type,
  short summary, one commit per feature.
- Conflict preference: **resolve automatically when the intended result is
  clear**. Keep both sides' unrelated work. If intent is ambiguous, or a
  resolution would drop work or needs a judgment call about behavior, stop,
  abort the rebase (`git rebase --abort`), and report that nothing was merged
  and which files conflict.
- All commands must be non-interactive. Never open an editor, never use
  `rebase -i`, and set `GIT_EDITOR=true` when git might prompt.

## 1. Identify the change

Find out what to merge from the request and the repository state:

- a branch, or a worktree under `.delta/worktrees/` or `.claude/worktrees/`
  (`git worktree list`, `git branch -a`), and/or
- uncommitted edits in the change's worktree.

If several candidates fit and the request does not say which, ask which one.

## 2. Preflight

1. In `/home/vin/projects/nimslides`, `git status --porcelain` and
   `git branch --show-current` must show branch `main` with no uncommitted
   changes that are not part of the requested change. If unrelated work is
   present, stop and report it rather than stashing or discarding it.
2. If the change has uncommitted edits, commit them **in the change's own
   worktree or branch**. Stage only the files that belong to the change
   (`git add <paths>`, never `git add -A` blindly) and write a Conventional
   Commit message. If the change is uncommitted directly on `main` in the main
   checkout, create a branch for it first (`git switch -c <name>`) and commit
   there, then switch back to `main`.
3. Scope guard: list the files changed relative to `main`
   (`git diff --name-only main...<branch>`). For a markdown-feature change,
   `docs/architecture.md` ("One feature = three files") limits it to:
   - `src/nimslides/features/<name>.nim`
   - `tests/features/test_<name>.nim`
   - `examples/features/<name>.md`

   If a feature change also touches core files (`src/nimslides/core/**`,
   `src/nimslides/core.nim`, `features.nim`, `render.nim`, `viewer.nim`,
   `nimslides.nimble`, `flake.nix`, `lock.json`), report the extra files and
   ask before merging. Non-feature changes (core, tooling, docs) that the user
   asked for are fine as they are.
4. If `nimslides.nimble` dependencies changed, `lock.json` must have been
   regenerated in the same change (`nim_lk > lock.json` inside `nix develop`;
   see the comment in `flake.nix` devShell). If it was not, stop and report.

## 3. Rebase onto `main`

From the change's worktree (or with the branch checked out there):

```sh
GIT_EDITOR=true git rebase main
```

Resolve conflicts following the conflict preference above
(`git add <file>`, then `GIT_EDITOR=true git rebase --continue`).

## 4. Required checks (on the rebased commit)

Run these in the change's worktree on the exact rebased tip that will become
`main`. All three must pass. If any one fails, can't run, or gives unclear
output, the merge is blocked: report it and do not fast-forward. Never skip a
check, edit a test to make it pass, or work around one.

```sh
nimble test          # task "test" in nimslides.nimble: runs tests/test_*.nim and tests/features/test_*.nim
nimble build         # bin "nimslides" from srcDir "src" (nimslides.nimble)
nph --check src tests  # formatter shipped in the flake devShell (flake.nix: pkgs.nph)
```

The tools come from the flake dev shell (`flake.nix` `devShells.default`, loaded
by `.envrc` `use flake`). If `nimble` or `nph` is not on `PATH`, run the commands
through `nix develop --command <cmd>`.

If you change anything to fix a check (for example running `nph src tests` to
format), commit the fix as part of the change and re-run **all** checks on the
new tip.

## 5. Fast-forward `main`

In `/home/vin/projects/nimslides` (on `main`):

```sh
git merge --ff-only <branch-or-commit>
```

If the fast-forward is refused (because `main` moved), go back to step 3.

## 6. Verify the result

- `git rev-parse main` equals the tip that was checked in step 4.
- `git status --porcelain` in the main checkout is clean.
- `git log --oneline -5 main` shows the change's commit(s) on top.

Report the new `main` commit hash and subject, the checks that passed, and that
nothing was pushed. If any step blocked, say clearly that the change has
**not** been merged and why.
