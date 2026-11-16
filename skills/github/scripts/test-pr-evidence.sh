#!/usr/bin/env bash
# Offline behavioral fixtures; gh is replaced on PATH for every invocation.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
python3 -I "$here/test-pr-evidence.py" "$here"
