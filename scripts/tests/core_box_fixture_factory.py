"""Deterministically materializes the positive Core Box audit fixture and its
five negative mutations in an isolated temporary directory.

Each named mutation changes exactly one dimension of an otherwise-valid
fixture so each failure classification stays unambiguous:

- ``missing-node``:      deletes the required ``LidPivot`` entity.
- ``duplicate-name``:    duplicates the ``RibbonRoot`` entity.
- ``wrong-digest``:      replaces the Full tier digest with 64 zeroes.
- ``oversized-texture``: replaces the basecolor texture with a real,
  valid 4096x1 PNG while leaving its reported manifest metadata untouched.
- ``missing-clip``:      removes ``memory.stamp`` from measured inventory.
"""

from __future__ import annotations

import json
import struct
import sys
import zlib
from pathlib import Path

_THIS_DIR = Path(__file__).resolve().parent
_SCRIPTS_DIR = _THIS_DIR.parent
if str(_SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(_SCRIPTS_DIR))

from core_box_asset_audit import CONFIG_PATH, canonical_json_bytes, sha256_bytes  # noqa: E402

MUTATIONS = (
    "missing-node",
    "duplicate-name",
    "wrong-digest",
    "oversized-texture",
    "missing-clip",
)

_TEXTURE_DIM = 64
_PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def _load_config() -> dict:
    return json.loads(CONFIG_PATH.read_text(encoding="utf-8"))


def _png_chunk(chunk_type: bytes, data: bytes) -> bytes:
    return (
        struct.pack(">I", len(data))
        + chunk_type
        + data
        + struct.pack(">I", zlib.crc32(chunk_type + data) & 0xFFFFFFFF)
    )


def _encode_png(width: int, height: int, rgb: tuple[int, int, int]) -> bytes:
    """Deterministically encode an uncompressed-source, 8-bit RGB PNG using
    only the standard library (``struct`` and ``zlib``)."""
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    raw_row = bytes([0]) + bytes(rgb) * width
    raw = raw_row * height
    idat = zlib.compress(raw, 9)
    return _PNG_SIGNATURE + _png_chunk(b"IHDR", ihdr) + _png_chunk(b"IDAT", idat) + _png_chunk(b"IEND", b"")


def write_core_box_fixture(root: Path, mutation: str | None = None) -> None:
    if mutation is not None and mutation not in MUTATIONS:
        raise ValueError(f"unknown mutation: {mutation!r}")

    config = _load_config()
    required_entities = list(config["requiredEntities"])
    clip_names = [clip["name"] for clip in config["clips"]]
    clip_defs = [
        {
            "name": clip["name"],
            "durationMilliseconds": clip["durationMilliseconds"],
            "authoringFrameCount": clip["authoringFrameCount"],
        }
        for clip in config["clips"]
    ]
    apple_usd_tools = config["appleUSDTools"]
    channel_entities = list(config["parameterizedChannels"][0]["entities"])

    (root / "textures").mkdir(parents=True, exist_ok=True)

    basecolor_dim = (4096, 1) if mutation == "oversized-texture" else (_TEXTURE_DIM, _TEXTURE_DIM)
    (root / "textures/basecolor.png").write_bytes(_encode_png(*basecolor_dim, (128, 96, 64)))
    (root / "textures/normal.png").write_bytes(_encode_png(_TEXTURE_DIM, _TEXTURE_DIM, (128, 128, 255)))
    (root / "textures/roughness.png").write_bytes(_encode_png(_TEXTURE_DIM, _TEXTURE_DIM, (200, 200, 200)))

    full_bin = b"CORE-BOX-FIXTURE-FULL-V1" * 4
    lite_bin = b"CORE-BOX-FIXTURE-LITE-V1" * 4
    (root / "full.bin").write_bytes(full_bin)
    (root / "lite.bin").write_bytes(lite_bin)

    full_sha = "0" * 64 if mutation == "wrong-digest" else sha256_bytes(full_bin)
    lite_sha = sha256_bytes(lite_bin)

    # Reported texture metadata always stays at the small authored
    # dimension -- the oversized-texture mutation leaves this untouched so
    # the audit is forced to read the real PNG bytes rather than trust it.
    textures_metadata = {
        "basecolor": {"width": _TEXTURE_DIM, "height": _TEXTURE_DIM},
        "normal": {"width": _TEXTURE_DIM, "height": _TEXTURE_DIM},
        "roughness": {"width": _TEXTURE_DIM, "height": _TEXTURE_DIM},
    }

    channel = {
        "name": "ribbon.pull",
        "samples": [0.0, 0.72, 1.0],
        "entities": channel_entities,
    }

    def tier_manifest(resource_name: str, byte_count: int, sha256: str) -> dict:
        return {
            "resourceName": resource_name,
            "byteCount": byte_count,
            "sha256": sha256,
            "clips": clip_defs,
            "channels": [channel],
            "textures": textures_metadata,
        }

    manifest = {
        "assetVersion": config["assetVersion"],
        "animationEncoding": config["animationEncoding"],
        "aoIntegration": config["aoIntegration"],
        "packagingComplianceMode": config["packagingComplianceMode"],
        "schemaVersion": config["schemaVersion"],
        "appleUSDTools": apple_usd_tools,
        "aoSourceSHA256": sha256_bytes(b"core-box-ao-source-fixture-v1"),
        "tiers": {
            "full": tier_manifest(config["tiers"]["full"]["resourceName"], len(full_bin), full_sha),
            "lite": tier_manifest(config["tiers"]["lite"]["resourceName"], len(lite_bin), lite_sha),
        },
    }
    (root / "manifest.json").write_bytes(canonical_json_bytes(manifest))

    full_entities = list(required_entities) + [f"PaperRest_{index:02d}" for index in range(24)]
    lite_entities = list(required_entities) + [f"PaperRest_{index:02d}" for index in range(10)]
    full_clips = list(clip_names)
    lite_clips = list(clip_names)

    if mutation == "missing-node":
        full_entities.remove("LidPivot")
        lite_entities.remove("LidPivot")
    if mutation == "duplicate-name":
        full_entities.append("RibbonRoot")
        lite_entities.append("RibbonRoot")
    if mutation == "missing-clip":
        full_clips.remove("memory.stamp")
        lite_clips.remove("memory.stamp")

    inventory = {
        "tiers": {
            "full": {
                "entities": full_entities,
                "clips": full_clips,
                "triangleCount": 4000,
                "renderableEntityCount": 40,
                "materialSlotCount": 3,
                "shadowCastingLightCount": 1,
                "dynamicLightCount": 1,
            },
            "lite": {
                "entities": lite_entities,
                "clips": lite_clips,
                "triangleCount": 2000,
                "renderableEntityCount": 20,
                "materialSlotCount": 3,
                "shadowCastingLightCount": 0,
                "dynamicLightCount": 1,
            },
        }
    }
    (root / "inventory.json").write_text(
        json.dumps(inventory, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
