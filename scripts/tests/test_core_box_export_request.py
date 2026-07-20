"""Contract tests for the deterministic Core Box static-stage request."""

from __future__ import annotations

import json
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
VALIDATOR = ROOT / "Assets/CoreBoxCharacter/scripts/validate-core-box-export-request.py"
CONFIG = ROOT / "Assets/CoreBoxCharacter/export-config.json"


class ExportRequestTests(unittest.TestCase):
    def test_pipeline_spike_selects_exact_tiers_and_clips(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            result = subprocess.run(
                ["/usr/bin/python3", "-B", str(VALIDATOR), "--config", str(CONFIG), "--output", directory, "--profile", "pipeline-spike-v1"],
                check=True, capture_output=True, text=True,
            )
        request = json.loads(result.stdout)
        self.assertEqual(request["tiers"], ["full", "lite"])
        self.assertEqual(request["clips"], ["capture.deposit", "draw.reveal", "idle.listen"])
        self.assertEqual(request["textureDimensions"]["full"], {"basecolor": 64, "normal": 64, "roughness": 64})

    def test_unknown_profile_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            result = subprocess.run(
                ["/usr/bin/python3", "-B", str(VALIDATOR), "--config", str(CONFIG), "--output", directory, "--profile", "wrong"],
                check=False, capture_output=True, text=True,
            )
        self.assertEqual(result.returncode, 64)

    def test_malformed_config_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory) / "config.json"
            config.write_text('{"exportProfiles":{"pipeline-spike-v1":null}}', encoding="utf-8")
            result = subprocess.run(
                ["/usr/bin/python3", "-B", str(VALIDATOR), "--config", str(config), "--output", directory, "--profile", "pipeline-spike-v1"],
                check=False, capture_output=True, text=True,
            )
        self.assertEqual(result.returncode, 64)


if __name__ == "__main__":
    unittest.main()
