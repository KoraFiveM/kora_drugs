#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
for test in test/*.lua; do lua "$test"; done
