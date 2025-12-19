#!/bin/bash
#
# Publish oak data: Import from Bear, export JSON, commit and push
#
# Usage:
#   ./publish.sh           # Incremental import + export + commit + push
#   ./publish.sh --full    # Full re-import + export + commit + push
#   ./publish.sh --dry-run # Show what would happen without making changes
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Parse flags
FULL_FLAG=""
DRY_RUN=false

for arg in "$@"; do
    case $arg in
        --full)
            FULL_FLAG="--full"
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            echo "Unknown option: $arg"
            echo "Usage: $0 [--full] [--dry-run]"
            exit 1
            ;;
    esac
done

echo "=== Oak Data Publishing Pipeline ==="
echo ""

# Step 1: Import from Bear
echo "Step 1: Importing from Bear..."
if [ "$DRY_RUN" = true ]; then
    ./oak import-bear --dry-run $FULL_FLAG
else
    ./oak import-bear $FULL_FLAG
fi
echo ""

# Step 2: Export to JSON
echo "Step 2: Exporting to JSON..."
JSON_PATH="../web/static/quercus_data.json"
if [ "$DRY_RUN" = true ]; then
    echo "Would export to: $JSON_PATH"
else
    ./oak export "$JSON_PATH"
    echo "Exported to: $JSON_PATH"
fi
echo ""

# Step 3: Check for changes
echo "Step 3: Checking for changes..."
cd ..

if [ "$DRY_RUN" = true ]; then
    echo "Would check git status:"
    git status --short cli/oak_compendium.db web/static/quercus_data.json
    echo ""
    echo "Dry run complete - no changes made"
    exit 0
fi

# Check if there are actual changes to commit
DB_CHANGED=$(git diff --name-only cli/oak_compendium.db 2>/dev/null || true)
JSON_CHANGED=$(git diff --name-only web/static/quercus_data.json 2>/dev/null || true)

if [ -z "$DB_CHANGED" ] && [ -z "$JSON_CHANGED" ]; then
    echo "No changes to publish"
    exit 0
fi

# Step 4: Commit changes
echo "Step 4: Committing changes..."
git add cli/oak_compendium.db web/static/quercus_data.json

# Generate commit message with timestamp
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
git commit -m "Update oak data: $TIMESTAMP"

# Step 5: Push to remote
echo ""
echo "Step 5: Pushing to remote..."
git push

echo ""
echo "=== Publishing complete ==="
