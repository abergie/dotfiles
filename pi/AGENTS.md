# Agent Persistent Rules

## Git Safety Rules (Mandatory)

1. Never commit directly to `main`.
2. Never push directly to `main`.
3. Always create/use a non-main branch for any code change.
4. Branch names must use a conventional prefix such as `feat/`, `fix/`, `chore/`, `docs/`, `refactor/`, or `test/` followed by a concise description (for example: `feat/pi-sandbox-extension`).
5. Always open a Pull Request for all changes.
6. If currently on `main`, stop and switch to a feature branch before editing, committing, or pushing.

## Enforcement Checklist (before commit)

- Confirm current branch is not `main`.
- Confirm current branch follows the `feat/`, `fix/`, `chore/`, `docs/`, `refactor/`, or `test/` naming convention.
- Confirm changes are scoped to task.
- Commit only on feature branch.
- Push branch and open/update PR.

## Local Guardrails (Installed)

- Global Git hooks path: `~/.git-hooks`
- `pre-commit`: blocks commits on `main`/`master`
- `pre-push`: blocks pushes involving `main`/`master`

To verify:

```bash
git config --global --get core.hooksPath
ls -l ~/.git-hooks
```

---

# Agent Operating Rules

## Scope

- Work only inside this repository.
- Make the smallest change that satisfies the request.
- Follow existing architecture, naming, formatting, and testing conventions.
- Do not modify unrelated files or perform opportunistic refactors.

## Allowed Without Confirmation

- Read repository files.
- Search the codebase.
- Edit source code, tests, and documentation related to the task.
- Run existing formatters, linters, type checks, and tests.
- Create temporary files under `/tmp`.
- Use read-only Git commands such as `git status`, `git diff`, `git log`, and `git show`.

## Confirm Before Doing

Ask before:

- Adding, removing, or upgrading dependencies.
- Running database migrations or modifying schemas.
- Changing infrastructure, deployment, CI/CD, authentication, or authorization.
- Modifying public APIs, persisted data formats, or shared contracts.
- Making broad refactors outside the requested scope.
- Accessing external services or sending repository content over the network.
- Running commands that may affect resources outside this repository.

Explain the proposed action, why it is needed, and its likely impact.

## Never Do

- Do not read or modify files outside this repository.
- Do not access `.env`, credentials, private keys, SSH files, cloud profiles, Kubernetes configs, or browser credentials.
- Do not print, copy, summarize, or transmit secrets.
- Do not disable security controls, tests, validation, or sandboxing to make a task pass.
- Do not run destructive commands such as:
  - `rm -rf` outside an explicitly created temporary directory
  - `git reset --hard`
  - `git clean -fd` or `git clean -fdx`
  - `git checkout -- .`
  - force pushes
  - destructive database or cloud commands
- Do not commit, push, publish, deploy, merge, or open a pull request unless explicitly requested.
- Do not modify lockfiles unless dependency changes were explicitly authorized.

## Git Safety

- Treat existing uncommitted changes as user-owned.
- Never discard or overwrite changes you did not create.
- Review `git status` and `git diff` before making broad edits.
- Do not amend existing commits.
- Do not change branches or create worktrees unless requested.

## Implementation

- Prefer targeted edits over rewriting whole files.
- Preserve backward compatibility unless the task explicitly changes a contract.
- Use existing utilities and patterns before introducing new abstractions.
- Do not introduce placeholder implementations, silent fallbacks, or swallowed errors.
- Add comments only where behavior is non-obvious.

## Validation

After making changes:

1. Run the narrowest relevant tests first.
2. Run the repository's formatter, linter, and type checker when applicable.
3. Do not fix unrelated failures.
4. Report any validation that could not be run and why.

## Final Response

Summarize:

- What changed.
- Which files changed.
- What validation ran and whether it passed.
- Any remaining risks, assumptions, or follow-up work.

Do not claim a command passed unless it was actually run successfully.
