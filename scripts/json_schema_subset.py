"""Dependency-free validator for the exact JSON Schema keyword subset used by
the Core Box asset manifest schema.

Only these keywords are understood; every other keyword found anywhere in a
schema document is rejected: ``$ref``, ``$defs``, ``type``, ``const``,
``enum``, ``required``, ``properties``, ``additionalProperties``, ``items``,
``minItems``, ``maxItems``, ``uniqueItems``, ``minimum``, ``maximum``,
``minLength``, and ``pattern``. Only local references beginning with
``#/$defs/`` are resolved.
"""

from __future__ import annotations

import re

ALLOWED_KEYWORDS = frozenset(
    {
        "$ref",
        "$defs",
        "type",
        "const",
        "enum",
        "required",
        "properties",
        "additionalProperties",
        "items",
        "minItems",
        "maxItems",
        "uniqueItems",
        "minimum",
        "maximum",
        "minLength",
        "pattern",
    }
)

_TYPE_CHECKS = {
    "object": lambda value: isinstance(value, dict),
    "array": lambda value: isinstance(value, list),
    "string": lambda value: isinstance(value, str),
    "boolean": lambda value: isinstance(value, bool),
    "integer": lambda value: isinstance(value, int) and not isinstance(value, bool),
    "number": lambda value: isinstance(value, (int, float)) and not isinstance(value, bool),
    "null": lambda value: value is None,
}


class SchemaError(ValueError):
    """Raised for both malformed schema documents and validation failures."""


def _walk_keywords(schema: object) -> None:
    if not isinstance(schema, dict):
        return
    for keyword in schema:
        if keyword not in ALLOWED_KEYWORDS:
            raise SchemaError(f"unsupported_keyword: {keyword}")
    if "properties" in schema:
        properties = schema["properties"]
        if not isinstance(properties, dict):
            raise SchemaError("properties must be an object")
        for sub_schema in properties.values():
            _walk_keywords(sub_schema)
    if "additionalProperties" in schema and isinstance(schema["additionalProperties"], dict):
        _walk_keywords(schema["additionalProperties"])
    if "items" in schema:
        _walk_keywords(schema["items"])
    if "$defs" in schema:
        defs = schema["$defs"]
        if not isinstance(defs, dict):
            raise SchemaError("$defs must be an object")
        for sub_schema in defs.values():
            _walk_keywords(sub_schema)


def _resolve_ref(ref: str, root_schema: dict) -> dict:
    if not isinstance(ref, str) or not ref.startswith("#/$defs/"):
        raise SchemaError(f"unsupported_ref: {ref!r}")
    name = ref[len("#/$defs/"):]
    defs = root_schema.get("$defs", {})
    if name not in defs:
        raise SchemaError(f"unresolved_ref: {ref!r}")
    return defs[name]


def _check_type(value: object, type_name: str) -> None:
    checker = _TYPE_CHECKS.get(type_name)
    if checker is None:
        raise SchemaError(f"unsupported_type: {type_name!r}")
    if not checker(value):
        raise SchemaError(f"type_mismatch: expected {type_name!r}, got {value!r}")


def _validate(value: object, schema: dict, root_schema: dict) -> None:
    if "$ref" in schema:
        _validate(value, _resolve_ref(schema["$ref"], root_schema), root_schema)
        return

    if "const" in schema and value != schema["const"]:
        raise SchemaError(f"const_mismatch: expected {schema['const']!r}, got {value!r}")

    if "enum" in schema and value not in schema["enum"]:
        raise SchemaError(f"enum_mismatch: {value!r} not in {schema['enum']!r}")

    if "type" in schema:
        _check_type(value, schema["type"])

    if isinstance(value, (int, float)) and not isinstance(value, bool):
        if "minimum" in schema and value < schema["minimum"]:
            raise SchemaError(f"minimum_violation: {value!r} < {schema['minimum']!r}")
        if "maximum" in schema and value > schema["maximum"]:
            raise SchemaError(f"maximum_violation: {value!r} > {schema['maximum']!r}")

    if isinstance(value, str):
        if "minLength" in schema and len(value) < schema["minLength"]:
            raise SchemaError(f"min_length_violation: {value!r}")
        if "pattern" in schema and re.fullmatch(schema["pattern"], value) is None:
            raise SchemaError(f"pattern_violation: {value!r} does not match {schema['pattern']!r}")

    if isinstance(value, dict):
        for key in schema.get("required", []):
            if key not in value:
                raise SchemaError(f"missing_required_property: {key}")
        properties = schema.get("properties", {})
        additional = schema.get("additionalProperties", True)
        for key, sub_value in value.items():
            if key in properties:
                _validate(sub_value, properties[key], root_schema)
            elif additional is False:
                raise SchemaError(f"additional_property_not_allowed: {key}")
            elif isinstance(additional, dict):
                _validate(sub_value, additional, root_schema)

    if isinstance(value, list):
        if "minItems" in schema and len(value) < schema["minItems"]:
            raise SchemaError(f"min_items_violation: {len(value)} < {schema['minItems']}")
        if "maxItems" in schema and len(value) > schema["maxItems"]:
            raise SchemaError(f"max_items_violation: {len(value)} > {schema['maxItems']}")
        if schema.get("uniqueItems"):
            seen: list = []
            for item in value:
                if item in seen:
                    raise SchemaError(f"unique_items_violation: {item!r}")
                seen.append(item)
        if "items" in schema:
            for item in value:
                _validate(item, schema["items"], root_schema)


def validate_json_schema(value: object, schema: dict) -> None:
    """Validate ``value`` against ``schema`` using only the frozen keyword subset.

    Raises :class:`SchemaError` if the schema document uses an unsupported
    keyword or an unresolvable ``$ref``, or if ``value`` does not satisfy the
    schema.
    """
    if not isinstance(schema, dict):
        raise SchemaError("schema document must be an object")
    _walk_keywords(schema)
    _validate(value, schema, schema)
