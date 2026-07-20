"""Shared Section 1.4 archive/result-bundle directory-evidence identity.

Implements the ``xcarchive-tree-sha256-v1`` / ``xcresult-tree-sha256-v1``
framing exactly once: every descendant of a root directory is enumerated by
repository-style relative POSIX path sorted by UTF-8 bytes, devices and
sockets are rejected, and each entry is framed as:

- regular file: ``path NUL "file" NUL <4-digit lowercase octal mode> NUL
  <decimal size> NUL <raw-file lowercase SHA-256> LF``
- symlink: ``path NUL "symlink" NUL <mode> NUL <UTF-8 link target> LF``
  (the link is never followed)
- directory: ``path NUL "directory" NUL <mode> LF``

mtimes, owner IDs, and the root entry itself are never included. The framed
bytes are concatenated in sorted order and hashed with SHA-256. The two
version labels share identical framing; the label only names which identity
kind the caller intends.
"""

from __future__ import annotations

import hashlib
import os
import stat
import sys
from pathlib import Path

KNOWN_VERSIONS = ("xcarchive-tree-sha256-v1", "xcresult-tree-sha256-v1")

_EXIT_USAGE = 64


def _mode_token(path: Path) -> bytes:
    mode = path.lstat().st_mode & 0o7777
    return format(mode, "04o").encode("ascii")


def _iter_relative_paths(root: Path) -> list[Path]:
    paths: list[Path] = []
    for candidate in root.rglob("*"):
        paths.append(candidate)
    paths.sort(key=lambda candidate: candidate.relative_to(root).as_posix().encode("utf-8"))
    return paths


def evidence_tree_digest(root: Path, version: str) -> str:
    """Compute the Section 1.4 directory-evidence SHA-256 digest for ``root``."""
    if version not in KNOWN_VERSIONS:
        raise ValueError(f"unknown_version: {version!r}")
    if not root.is_dir():
        raise ValueError(f"root_not_a_directory: {root}")

    framed = bytearray()
    for path in _iter_relative_paths(root):
        relative = path.relative_to(root).as_posix()
        info = path.lstat()
        mode_bytes = _mode_token(path)
        if stat.S_ISLNK(info.st_mode):
            target_text = os.readlink(path)
            framed.extend(relative.encode("utf-8"))
            framed.append(0)
            framed.extend(b"symlink")
            framed.append(0)
            framed.extend(mode_bytes)
            framed.append(0)
            framed.extend(str(target_text).encode("utf-8"))
            framed.extend(b"\n")
        elif stat.S_ISDIR(info.st_mode):
            framed.extend(relative.encode("utf-8"))
            framed.append(0)
            framed.extend(b"directory")
            framed.append(0)
            framed.extend(mode_bytes)
            framed.extend(b"\n")
        elif stat.S_ISREG(info.st_mode):
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
            framed.extend(relative.encode("utf-8"))
            framed.append(0)
            framed.extend(b"file")
            framed.append(0)
            framed.extend(mode_bytes)
            framed.append(0)
            framed.extend(str(info.st_size).encode("ascii"))
            framed.append(0)
            framed.extend(digest.encode("ascii"))
            framed.extend(b"\n")
        else:
            raise ValueError(f"forbidden_special_file: {relative}")

    return hashlib.sha256(bytes(framed)).hexdigest()


def _parse_args(argv: list[str]) -> dict[str, str] | None:
    args: dict[str, str] = {}
    index = 0
    while index < len(argv):
        token = argv[index]
        if token in ("--version", "--root") and index + 1 < len(argv):
            key = "version" if token == "--version" else "root"
            args[key] = argv[index + 1]
            index += 2
        else:
            return None
    if set(args) != {"version", "root"}:
        return None
    return args


def main(argv: list[str]) -> int:
    args = _parse_args(argv)
    if args is None:
        print(
            "usage: core_box_tree_digest.py --version xcarchive-tree-sha256-v1|xcresult-tree-sha256-v1 --root PATH",
            file=sys.stderr,
        )
        return _EXIT_USAGE
    if args["version"] not in KNOWN_VERSIONS:
        print(f"unknown_version: {args['version']}", file=sys.stderr)
        return _EXIT_USAGE
    root = Path(args["root"])
    if not root.is_dir():
        print(f"root_not_a_directory: {root}", file=sys.stderr)
        return _EXIT_USAGE
    digest = evidence_tree_digest(root, args["version"])
    sys.stdout.write(digest + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
