#!/usr/bin/env bash
set -euo pipefail

readonly ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

if [[ "$#" -ne 2 ]]; then
    echo "usage: $0 <archive.xcarchive> <release-manifest.json>" >&2
    exit 64
fi

archive="$1"
release_manifest="$2"
test -d "${archive}" || { echo "archive_not_found:${archive}" >&2; exit 66; }
test -s "${release_manifest}" || { echo "release_manifest_not_found:${release_manifest}" >&2; exit 66; }
/usr/bin/plutil -lint "${archive}/Info.plist" >/dev/null || { echo "archive_info_invalid" >&2; exit 65; }
app="${archive}/Products/Applications/SomedayBox.app"
test -d "${app}" || { echo "archived_app_missing" >&2; exit 65; }
test -s "${app}/SomedayBox" || { echo "archived_executable_missing" >&2; exit 65; }
/usr/bin/codesign --verify --deep --strict "${app}" || {
    echo "archived_app_signature_invalid" >&2
    exit 65
}

/usr/bin/python3 -B - "${archive}" "${release_manifest}" <<'PY'
import json
import hashlib
import plistlib
import sys
from pathlib import Path

sys.path.insert(0, str(Path.cwd() / "scripts"))
from core_box_tree_digest import evidence_tree_digest

archive = Path(sys.argv[1])
path = Path(sys.argv[2])
data = json.loads(path.read_text(encoding="utf-8"))
if not isinstance(data, dict) or data.get("manifestVersion") != 2 or "releaseGate" not in data:
    raise SystemExit("release_manifest_shape_invalid")
expected_tree = data.get("archive", {}).get("treeSHA256")
if expected_tree != evidence_tree_digest(archive, "xcarchive-tree-sha256-v1"):
    raise SystemExit("archive_tree_digest_mismatch")
app = archive / "Products" / "Applications" / "SomedayBox.app"
with (app / "Info.plist").open("rb") as stream:
    info = plistlib.load(stream)
if data.get("archive", {}).get("bundleIdentifier") != info.get("CFBundleIdentifier"):
    raise SystemExit("archive_bundle_identifier_mismatch")
for name, expected in (
    ("CoreBoxAssetManifest.json", data.get("coreBoxAssetIdentity", {}).get("manifestSHA256")),
    ("CoreBoxCharacterFull.usdz", data.get("coreBoxAssetIdentity", {}).get("fullTierSHA256")),
    ("CoreBoxCharacterLite.usdz", data.get("coreBoxAssetIdentity", {}).get("liteTierSHA256")),
):
    actual = hashlib.sha256((app / name).read_bytes()).hexdigest()
    if actual != expected:
        raise SystemExit(f"asset_digest_mismatch:{name}")
PY

for resource in CoreBoxCharacterFull.usdz CoreBoxCharacterLite.usdz CoreBoxAssetManifest.json; do
    test -s "${app}/${resource}" || {
        echo "archived_production_resource_missing:${resource}" >&2
        exit 65
    }
done
test -s "${app}/SomedayBox" || { echo "archived_executable_missing" >&2; exit 65; }

echo "[core-box package audit] Archived production resources, executable, and release-manifest shape passed."
