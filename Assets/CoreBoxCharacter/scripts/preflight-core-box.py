"""Read-only source validation for the Blender proof character."""

from __future__ import annotations

import argparse
import json
import math
import os
import sys
from pathlib import Path

import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Euler, Matrix, Vector


REQUIRED = {"BoxRoot", "BoxBody", "LidPivot", "LidMesh", "EyeLeftPivot", "EyeLeftMesh", "EyeRightPivot", "EyeRightMesh", "RibbonRoot", "RibbonJoint_01", "RibbonJoint_02", "RibbonJoint_03", "RibbonJoint_04", "RibbonJoint_05", "RibbonTip", "PaperPool", "PaperSpawn", "PaperExit", "PaperDeposit", "PaperReveal", "PaperVisual", "CurrentPaperAnchor", "MemorySeam", "DecorationRoot", "ShadowReceiver", "Hit_Lid", "Hit_Ribbon", "Hit_Box", "Hit_MemorySeam", "Camera_Default", "Camera_Peek", "Camera_Overview", "Light_Key", "Light_Fill"}
EXPECTED_FLAGS = {"debug": 0, "inspect": 0, "interactive": 0, "optimize": 0, "dont_write_bytecode": 1, "no_user_site": 1, "ignore_environment": 0, "verbose": 0, "bytes_warning": 0, "quiet": 0, "hash_randomization": 0, "isolated": 0, "dev_mode": False, "utf8_mode": 1, "safe_path": False, "warn_default_encoding": 0}
EXPECTED_ACTION_TARGETS = {
    "idle.listen": {"BoxRoot", "LidPivot", "RibbonRoot"},
    "capture.deposit": {"BoxRoot", "LidPivot", "PaperDeposit"},
    "draw.reveal": {"BoxRoot", "PaperVisual"},
}
RIBBON_MESH_PARENTS = {
    "RibbonMesh": "RibbonJoint_01",
    "RibbonSegment_02": "RibbonJoint_02",
    "RibbonSegment_03": "RibbonJoint_03",
    "RibbonSegment_04": "RibbonJoint_04",
    "RibbonSegment_05": "RibbonJoint_05",
    "RibbonTipMesh": "RibbonTip",
}


def require_startup_contract() -> None:
    """Reject interpreter drift before inspecting project-owned data."""
    actual = {name: getattr(sys.flags, name) for name in EXPECTED_FLAGS}
    if not __debug__ or actual != EXPECTED_FLAGS:
        raise RuntimeError(f"unexpected Python flags: {actual!r}")
    allowed = {"PYTHONPATH", "PYTHONHOME", "PYTHONUSERBASE", "PYTHONDONTWRITEBYTECODE", "PYTHONHASHSEED", "PYTHONNOUSERSITE"}
    for name, value in os.environ.items():
        if name.startswith("PYTHON") and name not in allowed:
            raise RuntimeError(f"unexpected Python environment key: {name}")
    for name in ("PYTHONPATH", "PYTHONHOME", "PYTHONUSERBASE"):
        if os.environ.get(name) != "":
            raise RuntimeError(f"{name} must be present and empty")


def action_value(action: bpy.types.Action, object_name: str, data_path: str, index: int, frame: int) -> float:
    """Read one real action-slot F-curve without changing the opened source scene."""
    slots = json.loads(action["coreBoxActionSlots"])
    slot = action.slots.get(slots[object_name])
    if slot is None:
        raise RuntimeError(f"{action.name} is missing {object_name}'s action slot")
    bag = action.layers[0].strips[0].channelbag(slot)
    curve = next((item for item in bag.fcurves if item.data_path == data_path and item.array_index == index), None)
    if curve is None:
        raise RuntimeError(f"{action.name} is missing {object_name}'s {data_path}[{index}]")
    return curve.evaluate(frame)


def require_close(actual: float, expected: float, label: str) -> None:
    """Keep motion tolerances explicit in the source preflight report path."""
    if not math.isclose(actual, expected, abs_tol=1e-5):
        raise RuntimeError(f"{label}: expected {expected}, got {actual}")


def ribbon_pull_screen_min_x(scene: bpy.types.Scene, camera: bpy.types.Object, pull: object) -> float:
    """Project the sampled ribbon chain and mesh bounds without mutating the source scene."""
    snapshots = pull["1.0"]
    cache: dict[str, Matrix] = {}

    def matrix_for(obj: bpy.types.Object) -> Matrix:
        if obj.name in cache:
            return cache[obj.name]
        if obj.name in snapshots:
            transform = snapshots[obj.name]
            local = Matrix.Translation(Vector(transform["location"])) @ Euler(transform["rotationEuler"]).to_matrix().to_4x4() @ Matrix.Diagonal((*transform["scale"], 1.0))
        else:
            local = obj.matrix_local.copy()
        cache[obj.name] = matrix_for(obj.parent) @ local if obj.parent else local
        return cache[obj.name]

    ribbon_names = ["RibbonRoot", *(f"RibbonJoint_{index:02d}" for index in range(1, 6)), "RibbonTip"]
    points = [matrix_for(bpy.data.objects[name]).translation for name in ribbon_names]
    for mesh_name in RIBBON_MESH_PARENTS:
        mesh = bpy.data.objects[mesh_name]
        points.extend(matrix_for(mesh) @ Vector(corner) for corner in mesh.bound_box)
    return min(world_to_camera_view(scene, camera, point).x for point in points)


def main() -> None:
    require_startup_contract()
    arguments = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", required=True, type=Path)
    parser.add_argument("--report", required=True, type=Path)
    args = parser.parse_args(arguments)
    config = json.loads(args.config.read_text(encoding="utf-8"))
    objects = set(bpy.data.objects.keys())
    missing = REQUIRED - objects
    if missing:
        raise RuntimeError(f"missing required objects: {sorted(missing)}")
    collections = {collection.name for collection in bpy.data.collections}
    expected_collections = {"SOURCE_SHARED", "EXPORT_FULL", "EXPORT_LITE"}
    if collections != expected_collections:
        raise RuntimeError(f"unexpected collections: {collections}")
    shared = bpy.data.collections["SOURCE_SHARED"]
    full = bpy.data.collections["EXPORT_FULL"]
    lite = bpy.data.collections["EXPORT_LITE"]
    if shared.name not in {child.name for child in full.children} or shared.name not in {child.name for child in lite.children}:
        raise RuntimeError("SOURCE_SHARED must be a child of both export collections")
    shared_objects = {object.name for object in shared.all_objects}
    full_objects = {object.name for object in full.all_objects}
    lite_objects = {object.name for object in lite.all_objects}
    if full_objects & lite_objects != shared_objects:
        raise RuntimeError("export scopes do not intersect exactly at SOURCE_SHARED")
    if any(f"PaperRest_{index:02d}" not in shared_objects for index in range(10)):
        raise RuntimeError("Lite paper anchors are missing from SOURCE_SHARED")
    if any(f"PaperRest_{index:02d}" not in full_objects or f"PaperRest_{index:02d}" in lite_objects for index in range(10, 24)):
        raise RuntimeError("Full-only paper anchors are not isolated")
    actions = {action.name for action in bpy.data.actions}
    expected_actions = {"idle.listen", "capture.deposit", "draw.reveal"}
    if actions != expected_actions:
        raise RuntimeError(f"unexpected actions: {actions}")
    action_targets: dict[str, list[str]] = {}
    action_frame_ranges: dict[str, list[int]] = {}
    action_channel_counts: dict[str, int] = {}
    for name, end in (("idle.listen", 60), ("capture.deposit", 34), ("draw.reveal", 45)):
        clip = bpy.data.actions[name]
        if not clip.slots or not clip.layers or tuple(round(value) for value in clip.frame_range) != (0, end):
            raise RuntimeError(f"{name} lacks the expected motion curve and frame range")
        try:
            slots = json.loads(clip["coreBoxActionSlots"])
        except (KeyError, TypeError, json.JSONDecodeError) as error:
            raise RuntimeError(f"{name} lacks action-slot metadata") from error
        if set(slots) != EXPECTED_ACTION_TARGETS[name]:
            raise RuntimeError(f"{name} animates the wrong objects: {sorted(slots)}")
        strip = clip.layers[0].strips[0]
        channels = [curve for bag in strip.channelbags for curve in bag.fcurves]
        if len(channels) <= 1:
            raise RuntimeError(f"{name} lacks multi-object transform curves")
        for curve in channels:
            frames = [round(point.co.x) for point in curve.keyframe_points]
            if not frames or frames[0] != 0 or frames[-1] != end:
                raise RuntimeError(f"{name} channel does not span its proof action")
        action_targets[name] = sorted(slots)
        action_frame_ranges[name] = [0, end]
        action_channel_counts[name] = len(channels)
    for name in ("Camera_Default", "Camera_Peek", "Camera_Overview"):
        if bpy.data.objects[name].type != "CAMERA":
            raise RuntimeError(f"{name} is not a camera")
    for name in ("Light_Key", "Light_Fill"):
        if bpy.data.objects[name].type != "LIGHT":
            raise RuntimeError(f"{name} is not a light")
    expected_materials = {"MAT_MaplePaper", "MAT_SageRibbon", "MAT_MossInk", "MAT_InteriorMemory", "MAT_ContactShadow"}
    if not expected_materials.issubset(set(bpy.data.materials.keys())):
        raise RuntimeError("proof material family is incomplete")
    images = {Path(image.filepath).name for image in bpy.data.images}
    if images != {"core-box-basecolor.png", "core-box-normal.png", "core-box-roughness.png"}:
        raise RuntimeError("runtime material maps must contain exactly basecolor, normal, and roughness")
    root = bpy.data.objects["BoxRoot"]
    ribbon = bpy.data.objects["RibbonRoot"]
    if bpy.context.scene.render.fps != 60 or bpy.context.scene.render.fps_base != 1.0:
        raise RuntimeError("proof actions must be authored at 60 fps")
    idle = bpy.data.actions["idle.listen"]
    require_close(action_value(idle, "BoxRoot", "rotation_euler", 0, 30), math.radians(1.5), "idle root lean")
    require_close(action_value(idle, "LidPivot", "rotation_euler", 0, 30), math.radians(3.0), "idle lid raise")
    require_close(action_value(idle, "RibbonRoot", "rotation_euler", 2, 6), 0.0, "idle ribbon delay")
    require_close(action_value(idle, "RibbonRoot", "rotation_euler", 2, 33), math.radians(2.0), "idle ribbon motion")
    require_close(action_value(idle, "BoxRoot", "rotation_euler", 0, 60), 0.0, "idle terminal root")
    require_close(action_value(idle, "LidPivot", "rotation_euler", 0, 60), 0.0, "idle terminal lid")
    capture = bpy.data.actions["capture.deposit"]
    compression = action_value(capture, "BoxRoot", "scale", 1, 17)
    if not 0.9879 <= compression <= 1.0001:
        raise RuntimeError("capture root compression exceeds 1.2%")
    require_close(action_value(capture, "LidPivot", "rotation_euler", 0, 34), 0.0, "capture terminal lid")
    require_close(action_value(capture, "PaperDeposit", "location", 1, 34), 0.19, "capture deposit terminal")
    draw = bpy.data.actions["draw.reveal"]
    require_close(action_value(draw, "PaperVisual", "location", 1, 0), 0.115, "draw spawn")
    require_close(action_value(draw, "PaperVisual", "location", 0, 22), 0.11, "draw exit")
    require_close(action_value(draw, "PaperVisual", "location", 1, 45), 0.22, "draw reveal")
    pull = root["core_box_ribbon_pull"]
    ribbon_targets = {"RibbonRoot", *(f"RibbonJoint_{index:02d}" for index in range(1, 6)), "RibbonTip"}
    expected_pull_targets = ribbon_targets | {"BoxRoot"}
    if set(pull) != {"0.0", "0.72", "1.0"} or any(set(pull[point]) != expected_pull_targets for point in pull):
        raise RuntimeError("ribbon pull snapshots are incomplete")
    if abs(pull["1.0"]["BoxRoot"]["rotationEuler"][0]) > math.radians(2.0):
        raise RuntimeError("ribbon pull root lean exceeds 2 degrees")
    for mesh_name, parent_name in RIBBON_MESH_PARENTS.items():
        mesh = bpy.data.objects.get(mesh_name)
        if mesh is None or mesh.parent is None or mesh.parent.name != parent_name:
            raise RuntimeError(f"{mesh_name} is not bound to {parent_name}")
    camera = bpy.data.objects["Camera_Default"]
    ribbon_screen_x = world_to_camera_view(bpy.context.scene, camera, ribbon.matrix_world.translation).x
    eye_screen_x = max(world_to_camera_view(bpy.context.scene, camera, bpy.data.objects[name].matrix_world.translation).x for name in ("EyeLeftPivot", "EyeRightPivot"))
    ribbon_pull_min_x = ribbon_pull_screen_min_x(bpy.context.scene, camera, pull)
    if ribbon_pull_min_x <= eye_screen_x + 0.025:
        raise RuntimeError("ribbon pull crosses an eye safe region")
    report = {
        "collections": sorted(collections), "actions": sorted(actions),
        "boxRootScale": list(root.scale), "ribbonRootTranslation": list(ribbon.location),
        "ribbonRootScreenX": ribbon_screen_x, "rightEyeSafeMaxX": eye_screen_x + 0.025,
        "ribbonPullTargets": sorted(ribbon_targets), "ribbonPullScreenMinX": ribbon_pull_min_x,
        "ribbonPullMeshCount": len(RIBBON_MESH_PARENTS),
        "actionTargets": action_targets, "actionFrameRanges": action_frame_ranges,
        "actionChannelCounts": action_channel_counts,
        "framesPerSecond": bpy.context.scene.render.fps,
        "configAssetVersion": config["assetVersion"],
    }
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, sort_keys=True) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
