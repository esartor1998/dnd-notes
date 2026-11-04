#!/usr/bin/env bash
# Reproducible setup for a clean checkout under npm 12 (git deps blocked by default).
# Usage: scripts/bootstrap.sh && npx quartz build
set -euo pipefail
cd "$(dirname "$0")/.."

# Bypass any url.insteadOf rule that rewrites https GitHub URLs to SSH (passphrase prompts).
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null GIT_TERMINAL_PROMPT=0
# Plugin installs run npm inside .quartz/plugins/<name>/, where the project .npmrc does not apply.
export NPM_CONFIG_ALLOW_GIT=all

npm ci --ignore-scripts
# Only esbuild and @parcel/watcher run install scripts (approved via allowScripts in package.json).
npm rebuild esbuild @parcel/watcher

# @quartz-community/utils is a git dep that npm installs without dist/ (prepare never runs for it,
# and its src/ is not packed). Build the lockfile-pinned commit and copy dist/ in.
u=node_modules/@quartz-community/utils
if [ ! -d "$u/dist" ]; then
  commit=$(node -p "require('./package-lock.json').packages['node_modules/@quartz-community/utils'].resolved.split('#')[1]")
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT
  git clone --quiet https://github.com/quartz-community/utils.git "$tmp/utils"
  git -C "$tmp/utils" checkout --quiet "$commit"
  (cd "$tmp/utils" && npm install --ignore-scripts --no-audit --no-fund && npm run build)
  cp -r "$tmp/utils/dist" "$u/dist"
fi

# Restore plugins pinned in quartz.lock.json; existing plugin dirs are kept (no --clean).
npx quartz plugin install || echo "bootstrap: plugin install reported failures (expected for already-installed plugins)"

# Plugins are cloned source-only; install deps and build any without dist/.
for d in .quartz/plugins/*/; do
  [ -f "$d/package.json" ] || continue
  [ -d "$d/dist" ] && continue
  (cd "$d" && npm install --ignore-scripts --no-audit --no-fund && npm run build)
done

# Regenerate .quartz/plugins/index.ts now that every dist/index.d.ts exists.
npx quartz plugin install || true
grep -q CustomOgImagesEmitterName .quartz/plugins/index.ts \
  || { echo "bootstrap: .quartz/plugins/index.ts is missing og-image exports" >&2; exit 1; }
