#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <image-or-folder> [more paths...]"
  exit 1
fi

xcrun simctl addmedia booted "$@"
echo "Imported to booted simulator Photos: $*"
