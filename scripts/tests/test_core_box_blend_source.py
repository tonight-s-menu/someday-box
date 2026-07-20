"""Integration coverage for the minimal Blender-authored Core Box proof."""

from __future__ import annotations

import json
import subprocess
import tempfile
import unittest
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
BLENDER_RUNNER = REPOSITORY_ROOT / "scripts/run-core-box-blender.sh"
BLEND_PATH = REPOSITORY_ROOT / "Assets/CoreBoxCharacter/CoreBoxCharacter.blend"
PREFLIGHT = REPOSITORY_ROOT / "Assets/CoreBoxCharacter/scripts/preflight-core-box.py"
CONFIG = REPOSITORY_ROOT / "Assets/CoreBoxCharacter/export-config.json"

EXPECTED_COLLECTIONS = {"SOURCE_SHARED", "EXPORT_FULL", "EXPORT_LITE"}
EXPECTED_ACTIONS = {"idle.listen", "capture.deposit", "draw.reveal"}
EXPECTED_ACTION_TARGETS = {
    "idle.listen": {"BoxRoot", "LidPivot", "RibbonRoot"},
    "capture.deposit": {"BoxRoot", "LidPivot", "PaperDeposit"},
    "draw.reveal": {"BoxRoot", "PaperVisual"},
}


def run_blender_preflight() -> dict[str, object]:
    """Run the source-only auditor through the pinned Blender launcher."""
    with tempfile.TemporaryDirectory() as directory:
        report = Path(directory) / "source-preflight.json"
        result = subprocess.run(
            [
                str(BLENDER_RUNNER),
                "--background",
                "--disable-autoexec",
                "--offline-mode",
                "--python-use-system-env",
                "--python-exit-code",
                "1",
                str(BLEND_PATH),
                "--python",
                str(PREFLIGHT),
                "--",
                "--config",
                str(CONFIG),
                "--report",
                str(report),
            ],
            check=True,
            capture_output=True,
            text=True,
            env={"BLENDER_BIN": "/Applications/Blender.app/Contents/MacOS/Blender"},
        )
        if not report.is_file():
            raise AssertionError(f"preflight did not write a report: {result.stderr}")
        return json.loads(report.read_text(encoding="utf-8"))


class BlendSourceTests(unittest.TestCase):
    def test_spike_source_has_side_ribbon_and_three_proof_actions(self) -> None:
        report = run_blender_preflight()
        self.assertEqual(set(report["collections"]), EXPECTED_COLLECTIONS)
        self.assertEqual(set(report["actions"]), EXPECTED_ACTIONS)
        self.assertEqual(tuple(report["boxRootScale"]), (1.0, 1.0, 1.0))
        self.assertAlmostEqual(report["ribbonRootTranslation"][0], 0.132, places=4)
        self.assertGreater(report["ribbonRootScreenX"], report["rightEyeSafeMaxX"])
        self.assertEqual(report["actionTargets"], {
            name: sorted(targets) for name, targets in EXPECTED_ACTION_TARGETS.items()
        })
        self.assertEqual(report["actionFrameRanges"], {
            "idle.listen": [0, 60],
            "capture.deposit": [0, 34],
            "draw.reveal": [0, 45],
        })
        self.assertTrue(all(count > 1 for count in report["actionChannelCounts"].values()))


if __name__ == "__main__":
    unittest.main()
