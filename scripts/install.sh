#!/bin/bash
# Builds, installs to /Applications and (re)launches WrapAround.
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/build-app.sh
pkill -x WrapAround 2>/dev/null || true; sleep 0.5
rm -rf /Applications/WrapAround.app
cp -R build/WrapAround.app /Applications/
open /Applications/WrapAround.app
echo "installed and launched /Applications/WrapAround.app"
