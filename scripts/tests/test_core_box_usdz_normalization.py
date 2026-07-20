"""Contract tests for byte-preserving USDZ timestamp normalization."""

from __future__ import annotations

import sys
import unittest
import zipfile
from io import BytesIO
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))

from core_box_usdz import FIXED_DOS_DATE, FIXED_DOS_TIME, normalize_zip_timestamps  # noqa: E402


class UsdzNormalizationTests(unittest.TestCase):
    def test_normalizer_changes_only_zip_time_fields(self) -> None:
        source = BytesIO()
        with zipfile.ZipFile(source, "w") as archive:
            archive.writestr("Root.usdc", b"root payload")
            archive.writestr("textures/paper.png", b"texture payload")
        normalized = normalize_zip_timestamps(source.getvalue())
        with zipfile.ZipFile(BytesIO(normalized)) as archive:
            self.assertEqual(archive.read("Root.usdc"), b"root payload")
            self.assertEqual(archive.read("textures/paper.png"), b"texture payload")
            for info in archive.infolist():
                self.assertEqual(info.date_time, (2000, 1, 1, 0, 0, 0))
        self.assertIn(FIXED_DOS_TIME.to_bytes(2, "little") + FIXED_DOS_DATE.to_bytes(2, "little"), normalized)


if __name__ == "__main__":
    unittest.main()
