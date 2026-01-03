# Web Release Template

Use this template to create a release tracking issue.

## Usage

```bash
# Create the release issue
bd create --title "Release web $(date +%Y.%m.%d.%H%M)" --type task --priority 0

# Then update the issue with this description template
bd update <issue-id> --description "$(cat .beads/templates/release-web-checklist.md)"
```

Or manually copy the checklist below into the issue description.

---

## Checklist

See `release-web-checklist.md` for the full checklist to copy into the issue.
