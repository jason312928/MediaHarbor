#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

swift build
APP_BINARY="$(swift build --show-bin-path)/MediaHarbor"
"$APP_BINARY" --self-test
