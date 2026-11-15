#!/usr/bin/env bash
# Read-only; see ../references/pr-evidence.md for arguments and exit codes.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 -I "$here/pr-evidence.py" ci "$@"
