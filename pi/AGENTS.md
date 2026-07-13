# Agent Persistent Rules

## Git Safety Rules (Mandatory)

1. Never commit directly to `main`.
2. Never push directly to `main`.
3. Always create/use a non-main branch for any code change.
4. Always open a Pull Request for all changes.
5. If currently on `main`, stop and switch to a feature branch before editing, committing, or pushing.

## Enforcement Checklist (before commit)

- Confirm current branch is not `main`.
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
