#!/usr/bin/env bash
set -euo pipefail

asset="Resources/CoreBox.usda"
manifest="Resources/CoreBoxAssetManifest.json"

test -s "$asset"
test -s "$manifest"
python3 -m json.tool "$manifest" >/dev/null

required=(BoxRoot BoxBody LidPivot LidMesh RibbonRoot PaperPool PaperReveal CurrentPaperAnchor MemorySeam Ground Camera_Default Camera_Overview Light_Key Light_Fill)
for name in "${required[@]}"; do
    rg -q "\"$name\"" "$asset"
    rg -q "\"$name\"" "$manifest"
done

rg -q '"remoteDependencies": false' "$manifest"
rg -q '"realityComposerProRequired": false' "$manifest"
echo "[core-box asset audit] Bundled source, entity contract, provenance, and local-only declaration passed."
