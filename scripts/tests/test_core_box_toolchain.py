"""Toolchain pin equality and fail-closed drift tests for Core Box."""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

_THIS_DIR = Path(__file__).resolve().parent
_SCRIPTS_DIR = _THIS_DIR.parent
if str(_SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(_SCRIPTS_DIR))

from core_box_toolchain import (  # noqa: E402
    CONFIG_PATH,
    PROVENANCE_PATH,
    ToolchainContractError,
    apple_usd_from_provenance,
    load_toolchain_contract,
)


class ToolchainContractTests(unittest.TestCase):
    def test_config_is_the_single_pin_source_and_provenance_must_match(self) -> None:
        contract = load_toolchain_contract(CONFIG_PATH, PROVENANCE_PATH)
        self.assertEqual(contract.apple_usd, apple_usd_from_provenance(PROVENANCE_PATH))

    def test_any_provenance_or_consumer_drift_fails_closed(self) -> None:
        for mutation in (
            "provenance-macos-build",
            "provenance-version-output",
            "provenance-tool-path",
            "provenance-tool-sha",
            "consumer-expected-sha",
        ):
            with self.subTest(mutation=mutation):
                self.assertToolchainContractFails(mutation, code="toolchain_contract_drift")

    def assertToolchainContractFails(self, mutation: str, *, code: str) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            config = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
            provenance = json.loads(PROVENANCE_PATH.read_text(encoding="utf-8"))

            if mutation == "provenance-macos-build":
                provenance["appleUSDTools"]["macOSBuild"] = "00A000"
            elif mutation == "provenance-version-output":
                provenance["appleUSDTools"]["versionOutput"] = "Apple USD Tools (0.0.0)"
            elif mutation == "provenance-tool-path":
                provenance["appleUSDTools"]["usdcat"]["path"] = "/usr/bin/usdcat-renamed"
            elif mutation == "provenance-tool-sha":
                provenance["appleUSDTools"]["usdchecker"]["sha256"] = "0" * 64
            elif mutation == "consumer-expected-sha":
                config["appleUSDTools"]["usdzip"]["sha256"] = "1" * 64
            else:
                raise ValueError(f"unknown mutation: {mutation}")

            config_path = root / "export-config.json"
            provenance_path = root / "provenance.json"
            config_path.write_text(json.dumps(config), encoding="utf-8")
            provenance_path.write_text(json.dumps(provenance), encoding="utf-8")

            with self.assertRaises(ToolchainContractError) as context:
                load_toolchain_contract(config_path, provenance_path)
            self.assertEqual(context.exception.code, code)


class ToolchainCLITests(unittest.TestCase):
    def test_unknown_option_exits_usage(self) -> None:
        sys.path.insert(0, str(_SCRIPTS_DIR))
        import core_box_toolchain

        exit_code = core_box_toolchain.main(["--bogus", "value"])
        self.assertEqual(exit_code, 64)

    def test_missing_blender_for_full_scope_exits_usage(self) -> None:
        import core_box_toolchain

        exit_code = core_box_toolchain.main(
            ["--source-root", str(core_box_toolchain.REPOSITORY_ROOT), "--scope", "full"]
        )
        self.assertEqual(exit_code, 64)

    def test_config_drift_via_cli_exits_contract_drift(self) -> None:
        import core_box_toolchain

        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            asset_dir = root / "Assets/CoreBoxCharacter"
            asset_dir.mkdir(parents=True)
            config = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
            provenance = json.loads(PROVENANCE_PATH.read_text(encoding="utf-8"))
            config["appleUSDTools"]["usdcat"]["sha256"] = "2" * 64
            (asset_dir / "export-config.json").write_text(json.dumps(config), encoding="utf-8")
            (asset_dir / "provenance.json").write_text(json.dumps(provenance), encoding="utf-8")

            exit_code = core_box_toolchain.main(["--source-root", str(root), "--scope", "apple-usd"])
            self.assertEqual(exit_code, 65)


if __name__ == "__main__":
    unittest.main()
