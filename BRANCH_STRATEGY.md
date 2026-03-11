# Branch Strategy — Mortgage Guardian 2.0

## Branches
- **`main`** — Production. Cloudflare Pages auto-deploys from here. Protected: requires PR to merge.
- **`develop`** — Active development. Safe to push directly.
- **`feature/*`** — Individual features branched from `develop` or `main`.

## Workflow
1. Create a feature branch: `git checkout -b feature/my-feature develop`
2. Do your work, commit, push
3. Open a PR to `main` when ready to deploy
4. Merge → Cloudflare auto-deploys to mortgageguardian.org

## For Claude Code / AI Agents
- Never push directly to `main` (blocked by ruleset)
- Always work on `develop` or a `feature/*` branch
- Open a PR to `main` when the work is ready

## Protection Rules (set in GitHub Settings → Rules → Rulesets)
- `main`: Require PR, block force pushes, restrict deletions
- `develop`: No restrictions (fast iteration)
