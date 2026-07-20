"""Single config-driven verifier for Core Box tool pins and live toolchain
identity.

``export-config.json`` is the single pin source. This module first requires
exact deep equality between ``export-config.json``'s closed ``appleUSDTools``
object (and pinned Blender identity) and the same values recorded in
``provenance.json``; any drift there is a contract error, independent of any
live machine state. Only after that contract holds does it measure the live
Xcode, Blender, macOS, and Apple USD tool identities named by the contract.

CLI:
    /usr/bin/python3 -B scripts/core_box_toolchain.py \\
        --source-root PATH --scope apple-usd|host|full [--blender PATH]

Exit codes:
    64  unknown options, missing arguments, or a caller-supplied expected
        version/hash (this CLI never accepts one)
    65  config/provenance drift
    66  live identity drift
"""

from __future__ import annotations

import hashlib
import json
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Mapping

REPOSITORY_ROOT = Path(__file__).resolve().parent.parent
CONFIG_PATH = REPOSITORY_ROOT / "Assets/CoreBoxCharacter/export-config.json"
PROVENANCE_PATH = REPOSITORY_ROOT / "Assets/CoreBoxCharacter/provenance.json"

_ALLOWED_SCOPES = ("apple-usd", "host", "full")

_EXIT_USAGE = 64
_EXIT_CONTRACT_DRIFT = 65
_EXIT_LIVE_DRIFT = 66


class ToolchainContractError(RuntimeError):
    def __init__(self, code: str, detail: str) -> None:
        super().__init__(f"{code}: {detail}")
        self.code = code
        self.detail = detail


@dataclass(frozen=True)
class ToolchainContract:
    apple_usd: Mapping[str, object]
    blender: Mapping[str, object]
    xcode: str


def _load_json(path: Path) -> dict:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise ToolchainContractError("toolchain_contract_drift", f"cannot read {path}: {error}") from error


def apple_usd_from_provenance(provenance_path: Path) -> Mapping[str, object]:
    provenance = _load_json(provenance_path)
    try:
        return provenance["appleUSDTools"]
    except KeyError as error:
        raise ToolchainContractError(
            "toolchain_contract_drift", "provenance missing appleUSDTools"
        ) from error


def load_toolchain_contract(config_path: Path, provenance_path: Path) -> ToolchainContract:
    """The only place config and provenance pins are compared. Any mismatch
    anywhere in the closed ``appleUSDTools`` tuple or the pinned Blender
    identity fails closed with ``toolchain_contract_drift``."""
    config = _load_json(config_path)
    provenance = _load_json(provenance_path)

    try:
        config_apple_usd = config["appleUSDTools"]
    except KeyError as error:
        raise ToolchainContractError("toolchain_contract_drift", "config missing appleUSDTools") from error
    provenance_apple_usd = apple_usd_from_provenance(provenance_path)
    if config_apple_usd != provenance_apple_usd:
        raise ToolchainContractError(
            "toolchain_contract_drift",
            f"config appleUSDTools {config_apple_usd!r} != provenance appleUSDTools {provenance_apple_usd!r}",
        )

    try:
        config_blender = config["blender"]
        provenance_blender = {
            "version": provenance["blender"]["version"],
            "buildHash": provenance["blender"]["buildHash"],
            "binarySHA256": provenance["blender"]["binarySHA256"],
        }
    except KeyError as error:
        raise ToolchainContractError("toolchain_contract_drift", "missing blender provenance fields") from error
    if config_blender != provenance_blender:
        raise ToolchainContractError(
            "toolchain_contract_drift",
            f"config blender {config_blender!r} != provenance blender {provenance_blender!r}",
        )

    try:
        xcode = provenance["xcode"]
    except KeyError as error:
        raise ToolchainContractError("toolchain_contract_drift", "provenance missing xcode") from error

    return ToolchainContract(apple_usd=config_apple_usd, blender=config_blender, xcode=xcode)


def _sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _run(argv: list[str]) -> str:
    result = subprocess.run(argv, capture_output=True, text=True, check=False)
    return (result.stdout + result.stderr).strip()


def verify_apple_usd(contract: ToolchainContract) -> None:
    apple_usd = contract.apple_usd
    macos_build = _run(["/usr/bin/sw_vers", "-buildVersion"])
    if macos_build != apple_usd["macOSBuild"]:
        raise ToolchainContractError(
            "live_identity_drift", f"macOS build {macos_build!r} != {apple_usd['macOSBuild']!r}"
        )
    for tool_name in ("usdcat", "usdchecker", "usdzip"):
        tool = apple_usd[tool_name]
        path = Path(tool["path"])
        if not path.is_absolute():
            raise ToolchainContractError("live_identity_drift", f"{tool_name} path must be absolute")
        version_output = _run([str(path), "--version"])
        if version_output != apple_usd["versionOutput"]:
            raise ToolchainContractError(
                "live_identity_drift",
                f"{tool_name} version output {version_output!r} != {apple_usd['versionOutput']!r}",
            )
        actual_sha = _sha256_file(path)
        if actual_sha != tool["sha256"]:
            raise ToolchainContractError(
                "live_identity_drift", f"{tool_name} sha256 {actual_sha} != {tool['sha256']}"
            )


def verify_host(contract: ToolchainContract) -> None:
    verify_apple_usd(contract)
    output = _run(["/usr/bin/xcodebuild", "-version"])
    lines = [line.strip() for line in output.splitlines() if line.strip()]
    if len(lines) < 2:
        raise ToolchainContractError("live_identity_drift", f"unexpected xcodebuild -version output: {output!r}")
    version = lines[0].split()[-1]
    build = lines[1].split()[-1]
    xcode_identity = f"{version} ({build})"
    if xcode_identity != contract.xcode:
        raise ToolchainContractError(
            "live_identity_drift", f"xcode identity {xcode_identity!r} != {contract.xcode!r}"
        )


def verify_blender(contract: ToolchainContract, blender_path: Path) -> None:
    verify_host(contract)
    if not blender_path.is_absolute():
        raise ToolchainContractError("live_identity_drift", "blender path must be absolute")
    resolved = blender_path.resolve()
    if not resolved.is_file():
        raise ToolchainContractError("live_identity_drift", f"blender binary not found at {resolved}")

    output = _run([str(resolved), "--version"])
    lines = output.splitlines()
    version_match = re.match(r"Blender (\S+(?: LTS)?)", lines[0]) if lines else None
    version = version_match.group(1) if version_match else ""
    if version != contract.blender["version"]:
        raise ToolchainContractError(
            "live_identity_drift", f"blender version {version!r} != {contract.blender['version']!r}"
        )

    build_hash = ""
    for line in lines:
        stripped = line.strip()
        if stripped.startswith("build hash:"):
            build_hash = stripped[len("build hash:"):].strip()
            break
    if build_hash != contract.blender["buildHash"]:
        raise ToolchainContractError(
            "live_identity_drift", f"blender build hash {build_hash!r} != {contract.blender['buildHash']!r}"
        )

    actual_sha = _sha256_file(resolved)
    if actual_sha != contract.blender["binarySHA256"]:
        raise ToolchainContractError(
            "live_identity_drift", f"blender sha256 {actual_sha} != {contract.blender['binarySHA256']}"
        )


def _parse_args(argv: list[str]) -> dict[str, str] | None:
    args: dict[str, str] = {}
    index = 0
    while index < len(argv):
        token = argv[index]
        if token in ("--source-root", "--scope", "--blender") and index + 1 < len(argv):
            key = {"--source-root": "source_root", "--scope": "scope", "--blender": "blender"}[token]
            args[key] = argv[index + 1]
            index += 2
        else:
            return None
    if "source_root" not in args or "scope" not in args:
        return None
    if args["scope"] not in _ALLOWED_SCOPES:
        return None
    if args["scope"] == "full" and "blender" not in args:
        return None
    return args


def main(argv: list[str]) -> int:
    args = _parse_args(argv)
    if args is None:
        print(
            "usage: core_box_toolchain.py --source-root PATH --scope apple-usd|host|full [--blender PATH]",
            file=sys.stderr,
        )
        return _EXIT_USAGE

    source_root = Path(args["source_root"])
    config_path = source_root / "Assets/CoreBoxCharacter/export-config.json"
    provenance_path = source_root / "Assets/CoreBoxCharacter/provenance.json"

    try:
        contract = load_toolchain_contract(config_path, provenance_path)
    except ToolchainContractError as error:
        print(str(error), file=sys.stderr)
        return _EXIT_CONTRACT_DRIFT

    try:
        if args["scope"] == "apple-usd":
            verify_apple_usd(contract)
        elif args["scope"] == "host":
            verify_host(contract)
        else:
            verify_blender(contract, Path(args["blender"]))
    except ToolchainContractError as error:
        print(str(error), file=sys.stderr)
        return _EXIT_LIVE_DRIFT

    print("toolchain identity verified", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
