# Release Process

This document describes how to release the Oak Compendium components.

## Version Format

All components use date-based versioning: `YYYY.MM.DD.HHMM`

- Example: `2025.01.03.1430` = January 3, 2025 at 2:30 PM
- Multiple releases per day increment the time component
- Versions are stored in `/version.json`

---

## Web Release Process

### For Humans

1. **Start a Claude Code session**
2. **Say:** "I want to release the web app" (or run `/release web`)
3. **Follow the prompts:**
   - Select the branch to release
   - Confirm or fix any outstanding work
   - Wait for tests to pass (or help fix failures)
   - Review the squash commit message
   - Confirm the merge to main
4. **Agent monitors GitHub Actions** and reports success/failure

### For AI Agents

When a user requests a web release, create a beads issue using the template below.
This ensures the release can be resumed if the session is interrupted.

```bash
# Create release issue from template
bd create --title "Release web YYYY.MM.DD.HHMM" --type task --priority 1
# Then copy the checklist from .beads/templates/release-web.md into the description
```

---

## Release Template (Web)

Copy this checklist into a beads issue for each release. Update status as you progress.

```markdown
## Release: Web vYYYY.MM.DD.HHMM

### Pre-flight
- [ ] **CHECKPOINT 1**: Branch selection
  - Selected branch: `_______________`
  - Current branch: `_______________`
  - Action taken: (switched/stayed/stashed)

- [ ] **CHECKPOINT 2**: Working tree clean
  - Outstanding changes: (none/committed/stashed)
  - Notes: _______________

### Testing
- [ ] **CHECKPOINT 3**: Unit tests
  - Command: `npm run test`
  - Result: (pass/fail)
  - If failed, issues fixed: _______________

- [ ] **CHECKPOINT 4**: E2E tests
  - Command: `npm run test:e2e`
  - Result: (pass/fail)
  - If failed, issues fixed: _______________

- [ ] **CHECKPOINT 5**: Build verification
  - Command: `npm run build`
  - Result: (pass/fail)
  - Version in build: _______________

### Version & Commit
- [ ] **CHECKPOINT 6**: Version updated
  - Previous version: _______________
  - New version: _______________
  - File: `/version.json`

- [ ] **CHECKPOINT 7**: Squash commit created
  - Commit message summary: _______________
  - Commit SHA: _______________

### Deployment
- [ ] **CHECKPOINT 8**: Merged to main
  - Merge commit SHA: _______________
  - Method: (merge/fast-forward)

- [ ] **CHECKPOINT 9**: GitHub Actions
  - Workflow run URL: _______________
  - Build status: (pending/pass/fail)
  - Deploy status: (pending/pass/fail)

### Verification
- [ ] **CHECKPOINT 10**: Production verification
  - Site accessible: https://oakcompendium.org
  - Version displayed correctly on About page: (yes/no)
  - Basic functionality works: (yes/no)

### Completion
- Release completed: (yes/no)
- Final notes: _______________
```

---

## Agent Instructions

When asked to release the web app:

### 1. Setup and Sync (BEFORE any other work)

```bash
# Fetch latest from origin
git fetch origin

# Check if branch needs rebasing onto main
git log --oneline HEAD..origin/main

# If there are commits on main, rebase first
git rebase origin/main

# Create tracking issue
bd create --title "Release web $(date +%Y.%m.%d.%H%M)" --type task --priority 0
bd update <issue-id> --status in_progress

# CRITICAL: Sync beads immediately so the tracking issue commit happens NOW
# not at the end (which would bury the release commit)
bd sync
```

This ensures:
- We're up to date with main before starting
- The beads commit for the tracking issue is early, not at the end

### 2. Branch Selection (Checkpoint 1)

```bash
# Show current branch
git branch --show-current

# Ask user which branch to release
# Options: current branch, list recent branches, or user specifies
```

If user needs to switch branches and has uncommitted work:
- Ask: stash, commit, or abort?

### 3. Clean Working Tree (Checkpoint 2)

```bash
git status --porcelain
```

If not clean:
- Show user what's outstanding
- Ask how to proceed

### 4. Run Tests (Checkpoints 3-4)

```bash
cd web
npm run test           # Unit tests
npm run test:e2e       # E2E tests (requires running dev server)
```

If tests fail:
- Show failure details
- Work with user to fix
- Re-run until passing
- Update checkpoint with fixes made

### 5. Build Verification (Checkpoint 5)

```bash
npm run build
grep -r "Version " dist/about/index.html  # Verify version in build
```

### 6. Update Version (Checkpoint 6)

```bash
# Generate new version
NEW_VERSION=$(date +%Y.%m.%d.%H%M)

# Update version.json
# Edit the "web" field to the new version
```

### 7. Create Squash Commit (Checkpoint 7)

```bash
# Get summary of changes since last release
git log main..HEAD --oneline

# Create commit with summary
git add version.json
git commit -m "Release web v${NEW_VERSION}

Changes in this release:
- [summarize key changes from commits]

Version: ${NEW_VERSION}"
```

If branch has multiple commits, offer to squash:
```bash
git rebase -i main  # Interactive rebase to squash
```

### 8. Merge to Main (Checkpoint 8)

```bash
# IMPORTANT: Don't checkout main directly (beads daemon uses it)
# Push branch directly to main instead

# First, ensure no uncommitted changes (especially beads)
git status --porcelain
# If beads changes exist, they should already be synced from step 1
# If new beads changes appeared, sync them BEFORE the release commit

# Push to main
git push origin <release-branch>:main
```

**Key point**: The release commit should be the LAST commit pushed to main.
If beads changes appear after the release commit, they will become the "top"
commit and the release notes will be buried. This is why we sync beads in step 1.

### 9. Monitor GitHub Actions (Checkpoint 9)

```bash
# Get the workflow run URL
gh run list --workflow=deploy.yml --limit 1

# Watch the run
gh run watch <run-id>
```

Report status to user. If failed, investigate and report errors.

### 10. Production Verification (Checkpoint 10)

- Open https://oakcompendium.org
- Check About page shows new version
- Verify basic functionality (search, navigation)

### 11. Complete Release

```bash
bd close <issue-id> --reason "Released web v${NEW_VERSION}"
```

### 12. Branch Cleanup

After verifying production is working, delete the release branch:

```bash
# Delete local branch (use -D since remote tracking branch is stale)
git branch -D <release-branch>

# Delete remote branch
git push origin --delete <release-branch>
```

**Note**: `-D` (force delete) is needed because the branch was pushed directly to `main`
rather than merged, so the remote tracking branch (`origin/<release-branch>`) is stale.
Git's `-d` flag incorrectly reports it as "not fully merged" when comparing against
the outdated remote tracking branch.

---

## Recovering from Interruption

If a release is interrupted:

1. Find the release issue: `bd list --status=in_progress`
2. Read the checkpoints to see where it stopped: `bd show <issue-id>`
3. Resume from the last incomplete checkpoint
4. Continue updating checkpoints as you progress

---

## Excluded from Releases

These changes do NOT require a release:

- Beads changes (`.beads/` directory)
- OpenSpec changes (`/openspec/` directory)
- Documentation-only changes (README, CLAUDE.md)
- CI/workflow changes (`.github/`)

---

## Rollback

If a release needs to be reverted:

### Web Rollback

```bash
# Revert the merge commit
git revert -m 1 <merge-commit-sha>
git push origin main

# GitHub Actions will redeploy previous version
```

Or re-run a previous successful deployment from GitHub Actions.

---

## Future: API Release

(To be added)

## Future: iOS Release

(To be added)
