"""Contract tests for deterministic Core Box USDA serialization."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parents[2] / "Assets/CoreBoxCharacter/scripts"
sys.path.insert(0, str(SCRIPT_DIR))

from core_box_usda import canonicalize_usda_text  # noqa: E402


class UsdaCanonicalizationTests(unittest.TestCase):
    def test_canonicalizer_sorts_nested_prim_blocks_without_changing_values(self) -> None:
        source = '''#usda 1.0
(
)
{
    def Xform "Zed" (
        customData = {
            string label = "Z"
        }
    )
    {
        def Mesh "Zulu"
        {
            int answer = 42
        }

        def Mesh "Alpha"
        {
            int answer = 7
        }
    }

    def Xform "Able"
    {
    }
}
'''
        expected = '''#usda 1.0
(
)
{
    def Xform "Able"
    {
    }

    def Xform "Zed" (
        customData = {
            string label = "Z"
        }
    )
    {
        def Mesh "Alpha"
        {
            int answer = 7
        }

        def Mesh "Zulu"
        {
            int answer = 42
        }
    }
}
'''
        self.assertEqual(canonicalize_usda_text(source), expected)


if __name__ == "__main__":
    unittest.main()
