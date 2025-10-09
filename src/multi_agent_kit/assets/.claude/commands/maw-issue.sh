#!/bin/bash
set -euo pipefail

# Wrapper to allow /maw-issue to reuse /maw.issue implementation

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
exec "$SCRIPT_DIR/maw.issue.sh" "$@"
