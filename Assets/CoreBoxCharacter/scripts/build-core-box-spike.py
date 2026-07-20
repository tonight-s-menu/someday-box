"""Build the deterministic, minimal Blender source used by the pipeline spike."""

from __future__ import annotations

import argparse
import math
import os
import sys
from pathlib import Path

import bpy
from mathutils import Vector


EXPECTED_FLAGS = {
    "debug": 0, "inspect": 0, "interactive": 0, "optimize": 0,
    "dont_write_bytecode": 1, "no_user_site": 1, "ignore_environment": 0,
    "verbose": 0, "bytes_warning": 0, "quiet": 0, "hash_randomization": 0,
    "isolated": 0, "dev_mode": False, "utf8_mode": 1, "safe_path": False,
    "warn_default_encoding": 0,
}


def require_startup_contract() -> None:
    """Keep builds deterministic and prevent ambient Python configuration."""
    actual = {name: getattr(sys.flags, name) for name in EXPECTED_FLAGS}
    if not __debug__ or actual != EXPECTED_FLAGS:
        raise RuntimeError(f"unexpected Python flags: {actual!r}")
    for name in ("PYTHONPATH", "PYTHONHOME", "PYTHONUSERBASE"):
        if os.environ.get(name) != "":
            raise RuntimeError(f"{name} must be present and empty")


def make_collection(name: str) -> bpy.types.Collection:
    collection = bpy.data.collections.new(name)
    return collection


def move_to_collection(obj: bpy.types.Object, collection: bpy.types.Collection) -> None:
    for existing in list(obj.users_collection):
        existing.objects.unlink(obj)
    collection.objects.link(obj)


def cube(name: str, size: tuple[float, float, float], location: tuple[float, float, float], collection: bpy.types.Collection, parent: bpy.types.Object | None = None) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    move_to_collection(obj, collection)
    obj.parent = parent
    return obj


def empty(name: str, location: tuple[float, float, float], collection: bpy.types.Collection, parent: bpy.types.Object | None = None) -> bpy.types.Object:
    obj = bpy.data.objects.new(name, None)
    obj.empty_display_type = "PLAIN_AXES"
    obj.location = location
    collection.objects.link(obj)
    obj.parent = parent
    return obj


def material(name: str, color: tuple[float, float, float, float]) -> bpy.types.Material:
    result = bpy.data.materials.new(name)
    result.diffuse_color = color
    result.use_nodes = True
    result.node_tree.nodes.get("Principled BSDF").inputs["Base Color"].default_value = color
    return result


def make_texture(path: Path, color: tuple[float, float, float, float]) -> None:
    image = bpy.data.images.new(path.stem, width=64, height=64, alpha=True)
    image.pixels.foreach_set(list(color) * (64 * 64))
    image.filepath_raw = str(path)
    image.file_format = "PNG"
    image.save()
    bpy.data.images.remove(image)


def action(name: str, obj: bpy.types.Object, end: int, rotation: float = 0.0) -> None:
    """Author a real non-looping root channel that returns to rest."""
    obj.animation_data_clear()
    for frame, value in ((0, 0.0), (end // 2, rotation), (end, 0.0)):
        obj.rotation_euler.x = value
        obj.keyframe_insert(data_path="rotation_euler", index=0, frame=frame)
    clip = obj.animation_data.action
    clip.name = name
    clip.use_fake_user = True


def build(output: Path) -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    root_collection = scene.collection
    shared = make_collection("SOURCE_SHARED")
    full = make_collection("EXPORT_FULL")
    lite = make_collection("EXPORT_LITE")
    root_collection.children.link(full)
    root_collection.children.link(lite)
    full.children.link(shared)
    lite.children.link(shared)

    root = empty("BoxRoot", (0.0, 0.0, 0.0), shared)
    body = cube("BoxBody", (0.30, 0.16, 0.22), (0.0, 0.08, 0.0), shared, root)
    lid_pivot = empty("LidPivot", (0.0, 0.155, -0.095), shared, root)
    lid = cube("LidMesh", (0.306, 0.034, 0.226), (0.0, 0.017, 0.095), shared, lid_pivot)
    left_eye = empty("EyeLeftPivot", (-0.052, 0.118, 0.111), shared, root)
    right_eye = empty("EyeRightPivot", (0.052, 0.118, 0.111), shared, root)
    cube("EyeLeftMesh", (0.016, 0.022, 0.004), (0.0, 0.0, 0.0), shared, left_eye)
    cube("EyeRightMesh", (0.016, 0.022, 0.004), (0.0, 0.0, 0.0), shared, right_eye)
    ribbon = empty("RibbonRoot", (0.132, 0.102, 0.086), shared, root)
    parent = ribbon
    for index, offset in enumerate(((0.011, -0.003, 0.0), (0.011, -0.006, 0.0), (0.011, -0.009, 0.0), (0.011, -0.012, 0.0), (0.011, -0.015, 0.0)), 1):
        parent = empty(f"RibbonJoint_{index:02d}", offset, shared, parent)
    empty("RibbonTip", (0.055, -0.030, 0.0), shared, parent)
    for name in ("PaperPool", "PaperSpawn", "PaperExit", "PaperDeposit", "PaperReveal", "CurrentPaperAnchor", "MemorySeam", "DecorationRoot", "ShadowReceiver", "Hit_Lid", "Hit_Ribbon", "Hit_Box", "Hit_MemorySeam", "Camera_Default", "Camera_Peek", "Camera_Overview", "Light_Key", "Light_Fill"):
        empty(name, (0.0, 0.0, 0.0), shared, root)
    paper_pool = bpy.data.objects["PaperPool"]
    for index in range(24):
        collection = shared if index < 10 else full
        empty(f"PaperRest_{index:02d}", ((index % 4 - 1.5) * 0.04, 0.10 + (index // 4) * 0.004, 0.0), collection, paper_pool)

    # The visible proof meshes keep all collision and lighting proxies explicit.
    ribbon_mesh = cube("RibbonMesh", (0.082, 0.008, 0.018), (0.042, -0.018, 0.0), shared, ribbon)
    seam_mesh = cube("MemorySeamMesh", (0.18, 0.003, 0.004), (0.0, 0.045, 0.111), shared, bpy.data.objects["MemorySeam"])
    shadow_mesh = cube("ShadowReceiverMesh", (0.240, 0.002, 0.105), (0.0, 0.001, 0.012), shared, bpy.data.objects["ShadowReceiver"])
    for name in ("Hit_Lid", "Hit_Ribbon", "Hit_Box", "Hit_MemorySeam"):
        cube(f"{name}_Mesh", (0.03, 0.03, 0.03), (0.0, 0.0, 0.0), shared, bpy.data.objects[name]).hide_render = True

    def camera(name: str, location: tuple[float, float, float]) -> None:
        placeholder = bpy.data.objects[name]
        bpy.data.objects.remove(placeholder, do_unlink=True)
        data = bpy.data.cameras.new(name)
        obj = bpy.data.objects.new(name, data)
        shared.objects.link(obj)
        obj.parent = root
        obj.location = location
        obj.rotation_euler = (0.0, 0.0, 0.0)
        rotation = (Vector((0.0, 0.08, 0.0)) - obj.location).to_track_quat("-Z", "Y").to_euler()
        rotation.rotate_axis("Z", math.pi)
        obj.rotation_euler = rotation

    camera("Camera_Default", (0.0, 0.20, 0.58))
    camera("Camera_Peek", (0.0, 0.24, 0.40))
    camera("Camera_Overview", (0.32, 0.25, 0.52))
    scene.camera = bpy.data.objects["Camera_Default"]
    for name, energy, shadows in (("Light_Key", 700.0, True), ("Light_Fill", 250.0, False)):
        placeholder = bpy.data.objects[name]
        bpy.data.objects.remove(placeholder, do_unlink=True)
        data = bpy.data.lights.new(name, type="AREA")
        data.energy = energy
        data.use_shadow = shadows
        obj = bpy.data.objects.new(name, data)
        shared.objects.link(obj)
        obj.parent = root

    colors = {
        "MAT_MaplePaper": (0.68, 0.38, 0.18, 1.0), "MAT_SageRibbon": (0.50, 0.66, 0.48, 1.0),
        "MAT_MossInk": (0.08, 0.16, 0.10, 1.0), "MAT_InteriorMemory": (0.94, 0.84, 0.68, 1.0),
        "MAT_ContactShadow": (0.0, 0.0, 0.0, 0.14),
    }
    for name, color in colors.items():
        material(name, color).use_fake_user = True
    body.data.materials.append(bpy.data.materials["MAT_MaplePaper"])
    lid.data.materials.append(bpy.data.materials["MAT_MaplePaper"])
    ribbon_mesh.data.materials.append(bpy.data.materials["MAT_SageRibbon"])
    seam_mesh.data.materials.append(bpy.data.materials["MAT_InteriorMemory"])
    shadow_mesh.data.materials.append(bpy.data.materials["MAT_ContactShadow"])
    textures = output.parent / "textures"
    textures.mkdir(parents=True, exist_ok=True)
    for filename, color in (("core-box-basecolor.png", colors["MAT_MaplePaper"]), ("core-box-normal.png", (0.5, 0.5, 1.0, 1.0)), ("core-box-roughness.png", (0.8, 0.8, 0.8, 1.0)), ("core-box-ao.png", (0.9, 0.9, 0.9, 1.0))):
        make_texture(textures / filename, color)

    action("idle.listen", root, 60, 0.026)
    action("capture.deposit", root, 34, 0.012)
    action("draw.reveal", root, 45, 0.020)
    root["core_box_ribbon_pull"] = '{"0.0": [0, 0, 0], "0.72": [0.01, 0, 0], "1.0": [0.02, 0, 0]}'
    bpy.context.view_layer.objects.active = root
    root.select_set(True)
    scene.frame_set(0)
    bpy.ops.wm.save_as_mainfile(filepath=str(output), check_existing=False)


def main() -> None:
    require_startup_contract()
    arguments = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args(arguments)
    build(args.output.resolve())


if __name__ == "__main__":
    main()
