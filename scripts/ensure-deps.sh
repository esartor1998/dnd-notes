#!/usr/bin/env bash
# Re-run bootstrap only when the dependency lockfiles changed since the last successful run.
set -euo pipefail
cd "$(dirname "$0")/.."
stamp=.quartz/.bootstrap-stamp
want=$(cat package-lock.json quartz.lock.json | sha256sum | cut -d' ' -f1)
if [ "$(cat "$stamp" 2>/dev/null || true)" != "$want" ]; then
  echo "ensure-deps: lockfiles changed, running bootstrap"
  scripts/bootstrap.sh
  mkdir -p .quartz && echo "$want" > "$stamp"
fi
