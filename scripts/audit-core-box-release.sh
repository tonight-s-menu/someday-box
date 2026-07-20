#!/usr/bin/env bash
set -euo pipefail

readonly ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

manifest="Resources/CoreBoxAssetManifest.json"
identity="Generated/CoreBoxAssetIdentity.generated.swift"
candidate_schema="docs/release/core-box-candidate-manifest.schema.json"
for path in "${manifest}" "${identity}"; do
    test -s "${path}" || {
        echo "[core-box release audit] FAIL: missing production identity input ${path}." >&2
        exit 1
    }
done
test -s "${candidate_schema}" || {
    echo "[core-box release audit] FAIL: missing external candidate manifest schema ${candidate_schema}." >&2
    exit 1
}

rg -q 'content\.camera[[:space:]]*=[[:space:]]*\.virtual' Features/Home/CoreBox/CoreBoxRealityStage.swift
rg -q 'SomedayBoxSchemaV3' Data/StoreGenerationBootstrap.swift
rg -q 'BackupDocumentCodecV3' App/SomedayBoxApp.swift
rg -q 'time-context-v2' Domain/DrawPolicy.swift
rg -q 'StoreRecoveryView' App/SomedayBoxApp.swift

if rg -n 'CoreBox\.usda|makeCoreBoxScene' App Application Data Domain Features DesignSystem ShareExtension SomedayBox.xcodeproj/project.pbxproj; then
    echo "[core-box release audit] FAIL: obsolete Core Box production path remains." >&2
    exit 1
fi

echo "[core-box release audit] Production identity inputs, virtual camera, schema, backup, policy, Recovery, and obsolete-path hard-cut passed."
