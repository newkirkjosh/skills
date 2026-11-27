#!/usr/bin/env bash
# Offline routing fixtures; every external git/gh/wt call passes a deny-write fake.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
status=0
python3 -I "$here/test-dev-state.py" "$here/dev-state.sh" || status=$?
python3 -I "$here/test-dev-state-real.py" "$here/dev-state.sh" || status=$?
exit "$status"
