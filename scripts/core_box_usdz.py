"""Byte-preserving normalization helpers for deterministic Core Box USDZ files."""

from __future__ import annotations


LOCAL_FILE_HEADER = b"PK\x03\x04"
CENTRAL_DIRECTORY_HEADER = b"PK\x01\x02"
END_OF_CENTRAL_DIRECTORY = b"PK\x05\x06"
FIXED_DOS_TIME = 0
FIXED_DOS_DATE = (20 << 9) | (1 << 5) | 1  # 2000-01-01


def _write_u16(data: bytearray, offset: int, value: int) -> None:
    data[offset : offset + 2] = value.to_bytes(2, "little")


def normalize_zip_timestamps(source: bytes) -> bytes:
    """Normalize ZIP header times without changing members, compression, or offsets."""
    data = bytearray(source)
    offset = 0
    while data[offset : offset + 4] == LOCAL_FILE_HEADER:
        flags = int.from_bytes(data[offset + 6 : offset + 8], "little")
        if flags & 0x08:
            raise ValueError("ZIP data descriptors are unsupported")
        compressed_size = int.from_bytes(data[offset + 18 : offset + 22], "little")
        name_length = int.from_bytes(data[offset + 26 : offset + 28], "little")
        extra_length = int.from_bytes(data[offset + 28 : offset + 30], "little")
        _write_u16(data, offset + 10, FIXED_DOS_TIME)
        _write_u16(data, offset + 12, FIXED_DOS_DATE)
        offset += 30 + name_length + extra_length + compressed_size
    while data[offset : offset + 4] == CENTRAL_DIRECTORY_HEADER:
        name_length = int.from_bytes(data[offset + 28 : offset + 30], "little")
        extra_length = int.from_bytes(data[offset + 30 : offset + 32], "little")
        comment_length = int.from_bytes(data[offset + 32 : offset + 34], "little")
        _write_u16(data, offset + 12, FIXED_DOS_TIME)
        _write_u16(data, offset + 14, FIXED_DOS_DATE)
        offset += 46 + name_length + extra_length + comment_length
    if data[offset : offset + 4] != END_OF_CENTRAL_DIRECTORY:
        raise ValueError("ZIP central directory is malformed")
    return bytes(data)
