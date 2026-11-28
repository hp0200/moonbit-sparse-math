#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

python_bin=
for candidate in python3 python; do
  if command -v "$candidate" >/dev/null 2>&1 &&
    "$candidate" -c "import sys" >/dev/null 2>&1; then
    python_bin="$candidate"
    break
  fi
done

if [ -z "$python_bin" ]; then
  echo "a working python3 or python is required for tools/mutate.py" >&2
  exit 2
fi

exec "$python_bin" tools/mutate.py "$@"
