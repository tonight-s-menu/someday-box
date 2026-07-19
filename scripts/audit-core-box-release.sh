#!/usr/bin/env bash
set -euo pipefail

manifest="docs/release/core-box-candidate-manifest.json"
asset="Resources/CoreBox.usda"
asset_manifest="Resources/CoreBoxAssetManifest.json"

python3 -m json.tool "$manifest" >/dev/null
expected=$(python3 -c 'import json; print(json.load(open("docs/release/core-box-candidate-manifest.json"))["coreBoxAssetDigest"])')
asset_expected=$(python3 -c 'import json; print(json.load(open("Resources/CoreBoxAssetManifest.json"))["assetSHA256"])')
actual=$(shasum -a 256 "$asset" | awk '{print $1}')
test "$expected" = "$actual"
test "$asset_expected" = "$actual"

rg -q 'content.camera = \.virtual' Features/Home/HomeView.swift
rg -q 'SomedayBoxSchemaV3' Data/StoreGenerationBootstrap.swift
rg -q 'BackupDocumentCodecV3' App/SomedayBoxApp.swift
rg -q 'time-context-v2' Domain/DrawPolicy.swift
rg -q 'StoreRecoveryView' App/SomedayBoxApp.swift

echo "[core-box release audit] Version, asset digest, virtual camera, schema, backup, policy, and Recovery declarations passed."
