#!/usr/bin/env bash
# Installs this repository's push guard (make hooks; safe to run again).
#
# The hook itself is versioned in scripts/githooks/pre-push. What's installed
# is a thin wrapper in git's hooks directory (wherever core.hooksPath points)
# that runs the checkout's own scripts/githooks/pre-push, so every worktree
# runs its branch's version. The guard must hold everywhere, so a copy is kept
# beside the wrapper and runs on a branch without it; running this again
# refreshes the copy. Git config is not changed.
set -euo pipefail

src=$(cd "$(dirname "$0")" && pwd)
hooks_dir=$(git rev-parse --git-path hooks)
mkdir -p "$hooks_dir"

hook=pre-push
target="$hooks_dir/$hook"
marker="# oaks: runs scripts/githooks/$hook"

if [[ -e "$target" ]] && ! grep -qx "$marker" "$target"; then
  echo "$target already has a $hook hook that isn't ours; leaving it alone." >&2
  echo "Call scripts/githooks/$hook from it, or move it aside and run this again." >&2
  exit 1
fi

cp "$src/$hook" "$hooks_dir/$hook.oaks"
chmod +x "$hooks_dir/$hook.oaks"

cat > "$target" <<HOOK
#!/bin/sh
$marker
hook="\$(git rev-parse --show-toplevel)/scripts/githooks/$hook"
[ -x "\$hook" ] && exec "\$hook" "\$@"
exec "\$(dirname "\$0")/$hook.oaks" "\$@"
HOOK
chmod +x "$target"
echo "Installed $target"
