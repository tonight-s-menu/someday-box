"""Missing/duplicate node, wrong digest, oversized texture, and missing clip
fail-closed tests for the Core Box audit fixtures."""

from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

_THIS_DIR = Path(__file__).resolve().parent
_SCRIPTS_DIR = _THIS_DIR.parent
if str(_SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(_SCRIPTS_DIR))

from core_box_asset_audit import AssetAuditError, audit_fixture  # noqa: E402
from core_box_fixture_factory import write_core_box_fixture  # noqa: E402


class ManifestContractTests(unittest.TestCase):
    def test_positive_fixture_audits_clean(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            write_core_box_fixture(root)
            audit_fixture(root)  # must not raise

    def test_negative_fixtures_fail_with_stable_codes(self) -> None:
        expected = {
            "missing-node": "missing_required_entity",
            "duplicate-name": "duplicate_entity_name",
            "wrong-digest": "tier_digest_mismatch",
            "oversized-texture": "texture_dimension_exceeded",
            "missing-clip": "clip_inventory_mismatch",
        }
        for name, code in expected.items():
            with self.subTest(name=name):
                with tempfile.TemporaryDirectory() as directory:
                    root = Path(directory)
                    write_core_box_fixture(root, mutation=name)
                    with self.assertRaisesRegex(AssetAuditError, f"^{code}:"):
                        audit_fixture(root)


if __name__ == "__main__":
    unittest.main()
