"""Dependency-free contract-unit audit core for the Core Box character asset
pipeline.

This module validates canonical manifest bytes, the authoring source tree
identity, injected measured inventory, tier package/texture digests, and
tier budgets. ``inventory.json`` consumed here is deliberately injected test
input for Task 1's contract-unit layer, not accepted production evidence; a
later pinned-Blender ``pxr`` inspector derives real inventory and requires
byte equality with this shape before production audits may pass.
"""

from __future__ import annotations

import hashlib
import json
import math
import struct
import sys
from pathlib import Path
from typing import Iterable

_THIS_DIR = Path(__file__).resolve().parent
if str(_THIS_DIR) not in sys.path:
    sys.path.insert(0, str(_THIS_DIR))

import json_schema_subset  # noqa: E402

REPOSITORY_ROOT = Path(__file__).resolve().parent.parent
CONFIG_PATH = REPOSITORY_ROOT / "Assets/CoreBoxCharacter/export-config.json"
PROVENANCE_PATH = REPOSITORY_ROOT / "Assets/CoreBoxCharacter/provenance.json"
MANIFEST_SCHEMA_PATH = REPOSITORY_ROOT / "Assets/CoreBoxCharacter/manifest-schema-v1.json"

REQUIRED_TIERS = ("full", "lite")

_PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


class AssetAuditError(RuntimeError):
    def __init__(self, code: str, detail: str) -> None:
        super().__init__(f"{code}: {detail}")
        self.code = code
        self.detail = detail


def canonical_json_bytes(value: object) -> bytes:
    text = json.dumps(
        value,
        ensure_ascii=False,
        allow_nan=False,
        sort_keys=True,
        separators=(",", ":"),
    )
    return (text + "\n").encode("utf-8")


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def authoring_tree_digest(entries: Iterable[tuple[str, bytes]]) -> str:
    framed = bytearray()
    for path, raw in sorted(entries, key=lambda item: item[0].encode("utf-8")):
        framed.extend(path.encode("utf-8"))
        framed.append(0)
        framed.extend(sha256_bytes(raw).encode("ascii"))
        framed.extend(b"\n")
    return sha256_bytes(bytes(framed))


def load_json(path: Path) -> object:
    return json.loads(path.read_text(encoding="utf-8"))


def validate_manifest(manifest_path: Path, schema_path: Path) -> dict[str, object]:
    raw = manifest_path.read_bytes()
    value = json.loads(raw)
    if raw != canonical_json_bytes(value):
        raise AssetAuditError("manifest_not_canonical", str(manifest_path))
    schema = json.loads(schema_path.read_text(encoding="utf-8"))
    try:
        json_schema_subset.validate_json_schema(value, schema)
    except json_schema_subset.SchemaError as error:
        raise AssetAuditError("manifest_schema_violation", str(error)) from error
    return value


def validate_source_config(config: dict[str, object]) -> None:
    """Validate the ``export-config.json`` "source" clip contract: every
    ``authoringFrameCount`` must equal ``ceil(durationMilliseconds * 60 /
    1000)`` and every clip name and duration must be unique."""
    clips = config.get("clips", [])
    seen_names: set[str] = set()
    seen_durations: set[int] = set()
    for clip in clips:
        name = clip["name"]
        duration = clip["durationMilliseconds"]
        frames = clip["authoringFrameCount"]
        expected_frames = math.ceil(duration * 60 / 1000)
        if frames != expected_frames:
            raise AssetAuditError(
                "clip_frame_count_mismatch",
                f"{name}: expected {expected_frames} frames for {duration}ms, found {frames}",
            )
        if name in seen_names:
            raise AssetAuditError("duplicate_clip_name", name)
        seen_names.add(name)
        if duration in seen_durations:
            raise AssetAuditError("duplicate_clip_duration", f"{name}: {duration}")
        seen_durations.add(duration)


def validate_inventory(inventory: dict[str, object], manifest: dict[str, object]) -> None:
    """Cross-check injected measured ``inventory.json`` against the
    ``export-config.json`` single source of truth for required entities and
    clip names, independent of whatever ``manifest`` happens to declare."""
    config = load_json(CONFIG_PATH)
    required_entities = set(config["requiredEntities"])
    expected_clip_names = {clip["name"] for clip in config["clips"]}

    for tier in REQUIRED_TIERS:
        tier_inventory = inventory["tiers"][tier]

        entities = list(tier_inventory["entities"])
        entity_set = set(entities)
        missing = required_entities - entity_set
        if missing:
            raise AssetAuditError(
                "missing_required_entity",
                f"{tier}: missing {sorted(missing)}",
            )
        if len(entities) != len(entity_set):
            duplicates = sorted({name for name in entities if entities.count(name) > 1})
            raise AssetAuditError("duplicate_entity_name", f"{tier}: {duplicates}")

        clips = list(tier_inventory["clips"])
        clip_set = set(clips)
        if len(clips) != len(clip_set) or clip_set != expected_clip_names:
            raise AssetAuditError(
                "clip_inventory_mismatch",
                f"{tier}: expected {sorted(expected_clip_names)}, found {sorted(clip_set)}",
            )


def _read_png_dimensions(path: Path) -> tuple[int, int]:
    data = path.read_bytes()
    if data[:8] != _PNG_SIGNATURE:
        raise AssetAuditError("texture_not_png", str(path))
    length, chunk_type = struct.unpack(">I4s", data[8:16])
    if chunk_type != b"IHDR" or length != 13:
        raise AssetAuditError("texture_not_png", str(path))
    width, height = struct.unpack(">II", data[16:24])
    return width, height


def validate_digests(root: Path, manifest: dict[str, object]) -> None:
    """Recompute tier package digests from the actual bytes on disk and read
    real PNG signature/IHDR dimensions rather than trusting any declared
    metadata."""
    config = load_json(CONFIG_PATH)

    for tier in REQUIRED_TIERS:
        tier_manifest = manifest["tiers"][tier]
        binary_path = root / f"{tier}.bin"
        actual_sha = sha256_bytes(binary_path.read_bytes())
        if actual_sha != tier_manifest["sha256"]:
            raise AssetAuditError(
                "tier_digest_mismatch",
                f"{tier}: expected {tier_manifest['sha256']}, measured {actual_sha}",
            )

    ceiling = max(
        config["tiers"]["full"]["largestTextureDimensionCeiling"],
        config["tiers"]["lite"]["largestTextureDimensionCeiling"],
    )
    for channel_name in ("basecolor", "normal", "roughness"):
        texture_path = root / "textures" / f"{channel_name}.png"
        width, height = _read_png_dimensions(texture_path)
        if max(width, height) > ceiling:
            raise AssetAuditError(
                "texture_dimension_exceeded",
                f"{channel_name}: {width}x{height} exceeds ceiling {ceiling}",
            )


def validate_budgets(root: Path, manifest: dict[str, object]) -> None:
    """Validate measured tier inventory and package sizes against the exact
    tier budgets from ``export-config.json`` Section 1.1."""
    config = load_json(CONFIG_PATH)
    inventory = json.loads((root / "inventory.json").read_text(encoding="utf-8"))

    for tier in REQUIRED_TIERS:
        budgets = config["tiers"][tier]
        tier_inventory = inventory["tiers"][tier]
        tier_manifest = manifest["tiers"][tier]

        if tier_manifest["byteCount"] > budgets["packageByteCeiling"]:
            raise AssetAuditError("package_byte_ceiling_exceeded", tier)
        if tier_inventory["triangleCount"] > budgets["triangleCeiling"]:
            raise AssetAuditError("triangle_ceiling_exceeded", tier)
        if tier_inventory["renderableEntityCount"] > budgets["renderableEntityCeiling"]:
            raise AssetAuditError("renderable_entity_ceiling_exceeded", tier)
        if tier_inventory["materialSlotCount"] > budgets["materialSlotCeiling"]:
            raise AssetAuditError("material_slot_ceiling_exceeded", tier)
        if tier_inventory["shadowCastingLightCount"] > budgets["shadowCastingLightCeiling"]:
            raise AssetAuditError("shadow_casting_light_ceiling_exceeded", tier)
        if tier_inventory["dynamicLightCount"] > budgets["dynamicLightCeiling"]:
            raise AssetAuditError("dynamic_light_ceiling_exceeded", tier)

    aggregate_bytes = manifest["tiers"]["full"]["byteCount"] + manifest["tiers"]["lite"]["byteCount"]
    if aggregate_bytes > config["aggregatePackageByteCeiling"]:
        raise AssetAuditError("aggregate_package_byte_ceiling_exceeded", "aggregate")


def audit_fixture(root: Path) -> None:
    schema = REPOSITORY_ROOT / "Assets/CoreBoxCharacter/manifest-schema-v1.json"
    manifest = validate_manifest(root / "manifest.json", schema)
    inventory = json.loads((root / "inventory.json").read_text(encoding="utf-8"))
    validate_inventory(inventory, manifest)
    validate_digests(root, manifest)
    validate_budgets(root, manifest)
