"""Contract coverage for the isolated Core Box reproducibility wrapper."""

from __future__ import annotations

import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
REPRO_CHECK = ROOT / "scripts/core-box-repro-check.sh"


class ReproCheckTests(unittest.TestCase):
    def test_repro_check_rejects_a_relative_checkout_path(self) -> None:
        result = subprocess.run(
            [str(REPRO_CHECK), "--checked-out-assets", ".", "--profile", "pipeline-spike-v1"],
            check=False,
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 64)

    def test_repro_check_rejects_an_unknown_profile_before_export(self) -> None:
        result = subprocess.run(
            [str(REPRO_CHECK), "--checked-out-assets", str(ROOT), "--profile", "wrong"],
            check=False,
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 64)


if __name__ == "__main__":
    unittest.main()
