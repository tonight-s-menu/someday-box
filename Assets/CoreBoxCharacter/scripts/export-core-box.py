"""Export deterministic static Full/Lite USDA stages from the proof source."""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

import bpy


EXPECTED_FLAGS = {"debug": 0, "inspect": 0, "interactive": 0, "optimize": 0, "dont_write_bytecode": 1, "no_user_site": 1, "ignore_environment": 0, "verbose": 0, "bytes_warning": 0, "quiet": 0, "hash_randomization": 0, "isolated": 0, "dev_mode": False, "utf8_mode": 1, "safe_path": False, "warn_default_encoding": 0}


def require_startup_contract() -> None:
    """Reject ambient Python configuration before touching the source scene."""
    actual = {name: getattr(sys.flags, name) for name in EXPECTED_FLAGS}
    if not __debug__ or actual != EXPECTED_FLAGS:
        raise RuntimeError(f"unexpected Python flags: {actual!r}")
    for name in ("PYTHONPATH", "PYTHONHOME", "PYTHONUSERBASE"):
        if os.environ.get(name) != "":
            raise RuntimeError(f"{name} must be present and empty")


def export_tier(config: dict[str, object], tier: str, output_root: Path) -> dict[str, object]:
    tier_config = config["tiers"][tier]
    collection = tier_config["collection"]
    if collection not in bpy.data.collections:
        raise RuntimeError(f"missing export collection: {collection}")
    stage = output_root / "stage" / tier
    stage.mkdir(parents=True, exist_ok=True)
    resource_name = tier_config["resourceName"]
    output = stage / Path(resource_name).with_suffix(".usda")
    result = bpy.ops.wm.usd_export(
        filepath=str(output), allow_unicode=False, author_blender_name=False, check_existing=False,
        collection=collection, evaluation_mode="RENDER", export_animation=False, export_armatures=True,
        export_cameras=True, export_curves=False, export_custom_properties=True, export_hair=False,
        export_lights=True, export_materials=True, export_mesh_colors=False, export_meshes=True,
        export_normals=True, export_points=False, export_shapekeys=True, export_subdivision="TESSELLATE",
        export_uvmaps=True, export_volumes=False, export_textures_mode="NEW", overwrite_textures=True,
        generate_preview_surface=True, generate_materialx_network=False, convert_world_material=False,
        convert_orientation=False, convert_scene_units="METERS", custom_properties_namespace="userProperties",
        incremental_frames=0, merge_parent_xform=False, meters_per_unit=1.0, ngon_method="BEAUTY",
        only_deform_bones=False, quad_method="SHORTEST_DIAGONAL", relative_paths=True,
        rename_uvmaps=False, root_prim_path="", selected_objects_only=False, triangulate_meshes=True,
        use_instancing=False, xform_op_mode="TRS",
    )
    if "FINISHED" not in result or not output.is_file():
        raise RuntimeError(f"USD export failed for {tier}")
    return {"tier": tier, "collection": collection, "stage": output.relative_to(output_root).as_posix()}


def main() -> None:
    require_startup_contract()
    arguments = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--profile", required=True)
    args = parser.parse_args(arguments)
    config = json.loads(args.config.read_text(encoding="utf-8"))
    if args.profile not in config.get("exportProfiles", {}):
        raise RuntimeError("unknown export profile")
    if args.profile != "pipeline-spike-v1":
        raise RuntimeError("static exporter supports pipeline-spike-v1 only")
    output_root = args.output.resolve()
    report = {"profile": args.profile, "tiers": [export_tier(config, tier, output_root) for tier in ("full", "lite")]}
    (output_root / "export-report.json").write_text(json.dumps(report, sort_keys=True, separators=(",", ":")) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
