"""Small, dependency-free canonicalizer for Blender-exported ASCII USD layers."""

from __future__ import annotations

import re
from pathlib import Path


PRIM_START = re.compile(r'^\s*(?:def|over|class)\s+(?:[A-Za-z_][A-Za-z0-9_]*\s+)?"([^"]+)"')


def canonicalize_sdf_prim_order(prim: object) -> None:
    """Stabilize sibling and property ordering for a pxr.Sdf PrimSpec tree."""
    for child in prim.nameChildren.values():
        canonicalize_sdf_prim_order(child)
    prim.nameChildrenOrder = sorted(prim.nameChildren.keys())
    # USD pseudo-roots have no editable property order.
    if not prim.path.IsAbsoluteRootPath():
        prim.propertyOrder = sorted(property_spec.name for property_spec in prim.properties)


def canonicalize_sdf_layer(layer: object) -> None:
    """Apply the Sdf ordering contract without requiring pxr at import time."""
    canonicalize_sdf_prim_order(layer.pseudoRoot)


def _matching_brace(lines: list[str], start: int) -> int:
    """Return the closing-brace line for the USD prim beginning at start."""
    depth = 0
    opened = False
    for index in range(start, len(lines)):
        depth += lines[index].count("{") - lines[index].count("}")
        opened = opened or "{" in lines[index]
        if opened and depth == 0:
            return index
    raise ValueError("unterminated USD prim block")


def _prim_body_open(lines: list[str], start: int) -> int:
    """Find a prim body's brace, skipping optional parenthesized metadata."""
    parentheses = 0
    for index in range(start, len(lines)):
        parentheses += lines[index].count("(") - lines[index].count(")")
        if parentheses == 0 and "{" in lines[index]:
            return index
    raise ValueError("USD prim lacks an opening brace")


def _canonicalize_body(lines: list[str]) -> list[str]:
    """Recursively sort immediate sibling prim blocks while preserving their text."""
    blocks: list[tuple[str, list[str]]] = []
    first_start: int | None = None
    last_end: int | None = None
    index = 0
    while index < len(lines):
        match = PRIM_START.match(lines[index])
        if match is None:
            index += 1
            continue
        end = _matching_brace(lines, _prim_body_open(lines, index))
        blocks.append((match.group(1), _canonicalize_block(lines[index : end + 1])))
        first_start = index if first_start is None else first_start
        last_end = end
        index = end + 1
    if first_start is None or last_end is None:
        return lines
    prefix = lines[:first_start]
    suffix = lines[last_end + 1 :]
    canonical = list(prefix)
    for block_index, (_, block) in enumerate(sorted(blocks, key=lambda value: value[0])):
        if canonical and canonical[-1].strip():
            canonical.append("\n")
        canonical.extend(block)
        if block_index != len(blocks) - 1:
            canonical.append("\n")
    canonical.extend(suffix)
    return canonical


def _canonicalize_block(lines: list[str]) -> list[str]:
    """Canonicalize nested prim blocks within one complete prim text fragment."""
    open_index = _prim_body_open(lines, 0)
    close_index = _matching_brace(lines, open_index)
    if close_index != len(lines) - 1:
        raise ValueError("unexpected text after USD prim block")
    return lines[: open_index + 1] + _canonicalize_body(lines[open_index + 1 : close_index]) + lines[close_index:]


def canonicalize_usda_text(text: str) -> str:
    """Return equivalent USDA text with every sibling prim block name-sorted."""
    lines = text.splitlines(keepends=True)
    first_prim = next((index for index, line in enumerate(lines) if PRIM_START.match(line)), len(lines))
    root_open = next((index for index, line in enumerate(lines[:first_prim]) if line.strip() == "{"), None)
    if root_open is None:
        # USDA normally authors pseudo-root children directly after its metadata;
        # only some generated layers use an explicit pseudo-root body.
        return "".join(_canonicalize_body(lines))
    root_close = _matching_brace(lines, root_open)
    if any(line.strip() for line in lines[root_close + 1 :]):
        raise ValueError("unexpected text after USD pseudo-root")
    return "".join(lines[: root_open + 1] + _canonicalize_body(lines[root_open + 1 : root_close]) + lines[root_close:])


def canonicalize_usda(path: Path) -> None:
    """Rewrite a USDA file only when Blender's prim write order is non-canonical."""
    original = path.read_text(encoding="utf-8")
    canonical = canonicalize_usda_text(original)
    if canonical != original:
        path.write_text(canonical, encoding="utf-8")
