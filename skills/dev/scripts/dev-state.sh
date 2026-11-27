#!/usr/bin/env bash
# Read-only pickup and lifecycle inspection; see ../references/dev-state.md.
set -euo pipefail
exec python3 -I "$(dirname -- "${BASH_SOURCE[0]}")/dev-state.py" "$@"
