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
