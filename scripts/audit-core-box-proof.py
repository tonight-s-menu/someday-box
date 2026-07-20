"""Fail-closed audit for the verification-only Core Box proof bundle."""

from __future__ import annotations

import hashlib
import json
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
FIXTURES = ROOT / "SomedayBoxTests/Fixtures"
GENERATED = ROOT / "SomedayBoxTests/Generated/CoreBoxProofIdentity.generated.swift"
PROJECT = ROOT / "SomedayBox.xcodeproj/project.pbxproj"
CONFIG = ROOT / "Assets/CoreBoxCharacter/export-config.json"

EXPECTED_RIBBON_ENTITIES = [
    "BoxRoot",
    "RibbonRoot",
    "RibbonJoint_01",
    "RibbonJoint_02",
    "RibbonJoint_03",
    "RibbonJoint_04",
    "RibbonJoint_05",
    "RibbonTip",
]
EXPECTED_RECIPES = {
    "idle.listen": ("BoxRoot", 1000),
    "capture.deposit": ("LidPivot", 560),
    "draw.reveal": ("PaperReveal", 750),
}


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def validate_transform(value: object, label: str) -> None:
    if not isinstance(value, dict) or set(value) != {"translation", "rotationDegrees", "scale"}:
        raise SystemExit(f"core_box_proof_transform_shape_invalid:{label}")
    for key in ("translation", "rotationDegrees", "scale"):
        components = value[key]
        if not isinstance(components, list) or len(components) != 3:
            raise SystemExit(f"core_box_proof_transform_components_invalid:{label}:{key}")
        if any(not isinstance(component, (int, float)) for component in components):
            raise SystemExit(f"core_box_proof_transform_non_numeric:{label}:{key}")


def validate_runtime_contract(report: dict) -> None:
    recipes = report.get("runtimeTransformRecipes")
    if not isinstance(recipes, list) or {recipe.get("name") for recipe in recipes} != set(EXPECTED_RECIPES):
        raise SystemExit("core_box_proof_runtime_recipe_names_invalid")
    for recipe in recipes:
        name = recipe["name"]
        controlled_entity, duration = EXPECTED_RECIPES[name]
        if recipe.get("durationMilliseconds") != duration:
            raise SystemExit(f"core_box_proof_runtime_duration_invalid:{name}")
        keyframes = recipe.get("keyframes")
        if not isinstance(keyframes, list) or not keyframes or keyframes[0].get("timeMilliseconds") != 0:
            raise SystemExit(f"core_box_proof_runtime_keyframes_invalid:{name}")
        if keyframes[-1].get("timeMilliseconds") != duration:
            raise SystemExit(f"core_box_proof_runtime_terminal_invalid:{name}")
        if any(frame.get("entity") != controlled_entity for frame in keyframes):
            raise SystemExit(f"core_box_proof_runtime_entity_invalid:{name}")
        times = [frame.get("timeMilliseconds") for frame in keyframes]
        if times != sorted(set(times)):
            raise SystemExit(f"core_box_proof_runtime_timeline_invalid:{name}")
        for index, frame in enumerate(keyframes):
            validate_transform(frame.get("transform"), f"{name}:{index}")


def validate_ribbon_contract(report: dict, required_entities: list[str]) -> None:
    samples = report.get("ribbonSamples")
    progress = report.get("ribbonSampleProgress")
    if progress != [0.0, 0.72, 1.0] or not isinstance(samples, list):
        raise SystemExit("core_box_proof_ribbon_contract_invalid")
    if [sample.get("progress") for sample in samples] != progress:
        raise SystemExit("core_box_proof_ribbon_progress_invalid")
    expected_names = set(EXPECTED_RIBBON_ENTITIES)
    if not expected_names.issubset(set(required_entities)):
        raise SystemExit("core_box_proof_ribbon_entities_not_required")
    for sample in samples:
        entities = sample.get("entities")
        if not isinstance(entities, list) or [item.get("entity") for item in entities] != EXPECTED_RIBBON_ENTITIES:
            raise SystemExit(f"core_box_proof_ribbon_entities_invalid:{sample.get('progress')}")
        for index, item in enumerate(entities):
            validate_transform(item.get("transform"), f"ribbon:{sample.get('progress')}:{index}")


def main() -> int:
    report_path = FIXTURES / "CoreBoxProofReport.json"
    report_bytes = report_path.read_bytes()
    report = json.loads(report_bytes)
    canonical = (json.dumps(report, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")
    if report_bytes != canonical or report.get("profile") != "pipeline-spike-v1":
        raise SystemExit("core_box_proof_report_invalid")
    if report.get("clips") != ["idle.listen", "capture.deposit", "draw.reveal"]:
        raise SystemExit("core_box_proof_clip_contract_invalid")
    if report.get("animationEncoding") != "runtimeTransformRecipesV1":
        raise SystemExit("core_box_proof_animation_encoding_invalid")
    config = json.loads(CONFIG.read_text(encoding="utf-8"))
    if report.get("requiredEntityNames") != config["requiredEntities"]:
        raise SystemExit("core_box_proof_entity_contract_invalid")
    required_entities = report["requiredEntityNames"]
    parent_map = report.get("parentByEntity")
    if not isinstance(parent_map, dict) or set(parent_map) != set(required_entities):
        raise SystemExit("core_box_proof_parent_contract_invalid")
    if parent_map.get("BoxRoot") != "" or parent_map.get("RibbonRoot") != "BoxRoot":
        raise SystemExit("core_box_proof_root_parent_invalid")
    validate_transform(report.get("rootRestTransform"), "rootRest")
    if report["rootRestTransform"] != {
        "translation": [0.0, 0.0, 0.0],
        "rotationDegrees": [0.0, 0.0, 0.0],
        "scale": [1.0, 1.0, 1.0],
    }:
        raise SystemExit("core_box_proof_root_rest_invalid")
    validate_runtime_contract(report)
    validate_ribbon_contract(report, required_entities)
    tier_files = {"full": "CoreBoxProofFull.usdz", "lite": "CoreBoxProofLite.usdz"}
    for tier, filename in tier_files.items():
        package = FIXTURES / filename
        if report["tiers"][tier]["sha256"] != digest(package):
            raise SystemExit(f"core_box_proof_digest_mismatch:{tier}")
        if report["tiers"][tier]["byteCount"] != package.stat().st_size:
            raise SystemExit(f"core_box_proof_size_mismatch:{tier}")
        if report["tiers"][tier].get("paperRestCount") != config["tiers"][tier]["paperRestCount"]:
            raise SystemExit(f"core_box_proof_paper_contract_invalid:{tier}")
    source = GENERATED.read_text(encoding="utf-8")
    expected = {
        "reportSHA256": hashlib.sha256(report_bytes).hexdigest(),
        "fullTierSHA256": report["tiers"]["full"]["sha256"],
        "liteTierSHA256": report["tiers"]["lite"]["sha256"],
    }
    for name, value in expected.items():
        if re.search(rf'static let {name} = "{value}"', source) is None:
            raise SystemExit(f"core_box_proof_identity_mismatch:{name}")
    project = PROJECT.read_text(encoding="utf-8")
    app_resources = project.split("A70000000000000000000001 /* Resources */ = {", 1)[1].split("\t\t};", 1)[0]
    if "CoreBoxProof" in app_resources:
        raise SystemExit("core_box_proof_in_production_resources")
    print("[core-box proof audit] Proof bytes, identity, and test-only resource boundary passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
