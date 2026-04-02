# Branch Protection Configuration

Recommended branch protection rules for the `main` branch.

## Required Status Checks

Configure these in **Settings > Branches > Branch protection rules > main**.

### Required (must pass before merge)

| Check Name | Workflow | What It Verifies |
|------------|----------|-----------------|
| `Lint & Test` | Backend CI | ESLint + Jest tests with coverage |
| `Lint & Build` | Frontend CI | Next.js lint + production build |

### Optional (informational, not blocking)

| Check Name | Workflow | Why Optional |
|------------|----------|-------------|
| `Build and Test` | iOS CI | Only runs when iOS files change; most PRs are backend/frontend |

## Recommended Settings

| Setting | Value | Rationale |
|---------|-------|-----------|
| Require a pull request before merging | Yes | Prevents direct pushes to main |
| Required approvals | 1 | Code review for every change |
| Require status checks to pass | Yes | Enforces CI green before merge |
| Require branches to be up to date | Yes | Prevents merge skew |
| Require conversation resolution | Yes | All review comments addressed |
| Allow force pushes | No | Protects commit history |
| Allow deletions | No | Protects the main branch |

## Setup Instructions

1. Go to your repository on GitHub
2. Navigate to **Settings** > **Branches**
3. Click **Add branch protection rule** (or edit existing)
4. Set **Branch name pattern** to `main`
5. Enable the settings listed above
6. Under **Require status checks to pass before merging**:
   - Search for and add `Lint & Test` (Backend CI)
   - Search for and add `Lint & Build` (Frontend CI)
7. Click **Save changes**

## Notes

- Status checks only appear in the dropdown after they have run at least once on the repository.
- The iOS CI workflow uses path filtering, so it only runs when Swift/Xcode files change. This is why it's listed as optional — it won't report a status on PRs that don't touch iOS code.
- Deployment workflows (planned for Phases 25-26) will be added as required checks when implemented.
