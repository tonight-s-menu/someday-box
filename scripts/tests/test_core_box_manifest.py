"""Canonicalization, source digest, tree-identity, schema, and budget unit
tests for the Core Box asset contract."""

from __future__ import annotations

import json
import os
import sys
import tempfile
import unittest
from pathlib import Path

_THIS_DIR = Path(__file__).resolve().parent
_SCRIPTS_DIR = _THIS_DIR.parent
if str(_SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(_SCRIPTS_DIR))

from core_box_asset_audit import (  # noqa: E402
    AssetAuditError,
    CONFIG_PATH,
    MANIFEST_SCHEMA_PATH,
    authoring_tree_digest,
    canonical_json_bytes,
    load_json,
    sha256_bytes,
    validate_budgets,
    validate_manifest,
    validate_source_config,
)
from core_box_tree_digest import evidence_tree_digest  # noqa: E402
from json_schema_subset import SchemaError, validate_json_schema  # noqa: E402
from core_box_fixture_factory import write_core_box_fixture  # noqa: E402


class ManifestContractTests(unittest.TestCase):
    def test_raw_utf8_v1_is_exact(self) -> None:
        value = {"z": 2, "a": {"β": 1, "a": 0}}
        self.assertEqual(
            canonical_json_bytes(value),
            b'{"a":{"a":0,"\xce\xb2":1},"z":2}\n',
        )

    def test_path_sha256_v1_is_path_sensitive(self) -> None:
        first = [("b.bin", b"B"), ("a.bin", b"A")]
        second = [("a.bin", b"A"), ("c.bin", b"B")]
        self.assertNotEqual(authoring_tree_digest(first), authoring_tree_digest(second))

    def test_path_sha256_v1_is_order_independent_but_byte_sorted(self) -> None:
        first = [("b.bin", b"B"), ("a.bin", b"A")]
        second = [("a.bin", b"A"), ("b.bin", b"B")]
        self.assertEqual(authoring_tree_digest(first), authoring_tree_digest(second))

    def test_path_sha256_v1_of_empty_tree_is_sha256_of_empty_bytes(self) -> None:
        self.assertEqual(authoring_tree_digest([]), sha256_bytes(b""))

    def test_evidence_tree_digest_binds_mode_and_symlink_target(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "nested").mkdir()
            (root / "nested/data.bin").write_bytes(b"data")
            (root / "alias").symlink_to("nested/data.bin")
            first = evidence_tree_digest(root, version="xcresult-tree-sha256-v1")
            (root / "nested/data.bin").chmod(0o600)
            second = evidence_tree_digest(root, version="xcresult-tree-sha256-v1")
            self.assertNotEqual(first, second)
            self.assertEqual((root / "alias").readlink().as_posix(), "nested/data.bin")

    def test_evidence_tree_digest_excludes_mtime_owner_and_root_entry(self) -> None:
        with tempfile.TemporaryDirectory() as first_dir, tempfile.TemporaryDirectory() as second_dir:
            first_root = Path(first_dir)
            second_root = Path(second_dir)
            (first_root / "data.bin").write_bytes(b"stable-bytes")
            (second_root / "data.bin").write_bytes(b"stable-bytes")
            os.utime(first_root / "data.bin", (1000, 1000))
            os.utime(second_root / "data.bin", (2000000000, 2000000000))
            first = evidence_tree_digest(first_root, version="xcresult-tree-sha256-v1")
            second = evidence_tree_digest(second_root, version="xcresult-tree-sha256-v1")
            self.assertEqual(first, second)

    def test_evidence_tree_digest_rejects_forbidden_special_files(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            os.mkfifo(root / "fifo")
            with self.assertRaises(ValueError):
                evidence_tree_digest(root, version="xcresult-tree-sha256-v1")

    def test_evidence_tree_digest_rejects_unknown_version(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(ValueError):
                evidence_tree_digest(Path(directory), version="bogus-v1")

    def test_evidence_tree_digest_rejects_non_directory_root(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            not_a_directory = Path(directory) / "file.bin"
            not_a_directory.write_bytes(b"x")
            with self.assertRaises(ValueError):
                evidence_tree_digest(not_a_directory, version="xcresult-tree-sha256-v1")

    def test_xcarchive_and_xcresult_framing_is_identical_apart_from_the_label(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "nested").mkdir()
            (root / "nested/data.bin").write_bytes(b"identical-framing")
            (root / "alias").symlink_to("nested/data.bin")
            archive_digest = evidence_tree_digest(root, version="xcarchive-tree-sha256-v1")
            result_digest = evidence_tree_digest(root, version="xcresult-tree-sha256-v1")
            self.assertEqual(archive_digest, result_digest)

    def test_source_config_frame_count_formula_and_uniqueness_hold_for_the_real_config(self) -> None:
        config = load_json(CONFIG_PATH)
        validate_source_config(config)  # must not raise

    def test_source_config_rejects_wrong_frame_count(self) -> None:
        config = json.loads(json.dumps(load_json(CONFIG_PATH)))
        config["clips"][0]["authoringFrameCount"] += 1
        with self.assertRaisesRegex(AssetAuditError, "^clip_frame_count_mismatch:"):
            validate_source_config(config)

    def test_source_config_rejects_duplicate_clip_name(self) -> None:
        config = json.loads(json.dumps(load_json(CONFIG_PATH)))
        config["clips"][1]["name"] = config["clips"][0]["name"]
        config["clips"][1]["durationMilliseconds"] = config["clips"][0]["durationMilliseconds"]
        config["clips"][1]["authoringFrameCount"] = config["clips"][0]["authoringFrameCount"]
        with self.assertRaisesRegex(AssetAuditError, "^duplicate_clip_name:"):
            validate_source_config(config)

    def test_source_config_rejects_duplicate_clip_duration(self) -> None:
        config = json.loads(json.dumps(load_json(CONFIG_PATH)))
        config["clips"][1]["durationMilliseconds"] = config["clips"][0]["durationMilliseconds"]
        config["clips"][1]["authoringFrameCount"] = config["clips"][0]["authoringFrameCount"]
        with self.assertRaisesRegex(AssetAuditError, "^duplicate_clip_duration:"):
            validate_source_config(config)

    def test_json_schema_subset_rejects_unsupported_keyword(self) -> None:
        with self.assertRaises(SchemaError):
            validate_json_schema({"answer": 1}, {"type": "object", "format": "email"})

    def test_json_schema_subset_resolves_local_defs_refs(self) -> None:
        schema = {
            "$ref": "#/$defs/positiveInt",
            "$defs": {"positiveInt": {"type": "integer", "minimum": 1}},
        }
        validate_json_schema(5, schema)
        with self.assertRaises(SchemaError):
            validate_json_schema(0, schema)

    def test_json_schema_subset_rejects_unresolvable_external_ref(self) -> None:
        with self.assertRaises(SchemaError):
            validate_json_schema({}, {"$ref": "https://example.com/schema.json"})

    def test_manifest_schema_accepts_the_positive_fixture(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            write_core_box_fixture(root)
            manifest = validate_manifest(root / "manifest.json", MANIFEST_SCHEMA_PATH)
            self.assertEqual(manifest["assetVersion"], "core-box-character-v1")

    def test_validate_manifest_rejects_non_canonical_bytes(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            write_core_box_fixture(root)
            manifest_value = json.loads((root / "manifest.json").read_bytes())
            (root / "manifest.json").write_text(json.dumps(manifest_value, indent=2), encoding="utf-8")
            with self.assertRaisesRegex(AssetAuditError, "^manifest_not_canonical:"):
                validate_manifest(root / "manifest.json", MANIFEST_SCHEMA_PATH)

    def test_validate_manifest_rejects_schema_violation(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            write_core_box_fixture(root)
            manifest_value = json.loads((root / "manifest.json").read_bytes())
            del manifest_value["aoIntegration"]
            (root / "manifest.json").write_bytes(canonical_json_bytes(manifest_value))
            with self.assertRaisesRegex(AssetAuditError, "^manifest_schema_violation:"):
                validate_manifest(root / "manifest.json", MANIFEST_SCHEMA_PATH)

    def test_validate_budgets_passes_for_the_positive_fixture(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            write_core_box_fixture(root)
            manifest = validate_manifest(root / "manifest.json", MANIFEST_SCHEMA_PATH)
            validate_budgets(root, manifest)  # must not raise

    def test_validate_budgets_rejects_triangle_ceiling_overflow(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            write_core_box_fixture(root)
            manifest = validate_manifest(root / "manifest.json", MANIFEST_SCHEMA_PATH)
            inventory = json.loads((root / "inventory.json").read_text(encoding="utf-8"))
            inventory["tiers"]["full"]["triangleCount"] = 999_999_999
            (root / "inventory.json").write_text(json.dumps(inventory), encoding="utf-8")
            with self.assertRaisesRegex(AssetAuditError, "^triangle_ceiling_exceeded:"):
                validate_budgets(root, manifest)


if __name__ == "__main__":
    unittest.main()
