#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPOSITORY_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${REPOSITORY_ROOT}"

failures=0
while IFS= read -r main_file; do
    if rg -n '^[[:space:]]*@main([[:space:]]|$)' "${main_file}"; then
        echo "[build-structure audit] FAIL: ${main_file} combines Swift's implicit main.swift entry point with @main." >&2
        failures=$((failures + 1))
    fi
done < <(rg --files -g 'main.swift' -g '!**/.build/**' -g '!**/DerivedData/**')

if (( failures > 0 )); then
    echo "[build-structure audit] ${failures} conflicting entry point(s) found." >&2
    exit 1
fi

echo "[build-structure audit] Swift entry points are unambiguous."
