"""Finalize retained Nim check evidence without changing behavioral receipts.

Nix archives output mtimes at epoch 1. After the checks finish, validate Nim's
recorded output mtimes and archive them at that same epoch. Only the timestamp
string's bytes change in a cache record; compiler output contents never change.
This is an archive format, not wall-clock execution provenance.
"""
import argparse
from datetime import datetime
import json
import os
from pathlib import Path
import re


EPOCH = 1
TIMESTAMP = "1970-01-01T00:00:01+00:00"
POLICY = "artifact-retention.txt"
TIMESTAMP_FIELD = re.compile(
    rb'"outputLastModificationTime"\s*:\s*("(?:[^"\\]|\\.)*")'
)


def unique_object(pairs):
    """Reject ambiguous metadata, including duplicate escaped key spellings."""
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("Duplicate cache key: " + key)
        result[key] = value
    return result


def reject_constant(value):
    """Python's permissive NaN/Infinity extensions are not JSON metadata."""
    raise ValueError("Non-JSON numeric constant: " + value)


def retained_file(path, root):
    """Require an existing regular file wholly within the retained archive."""
    if not path.is_absolute() or path.is_symlink():
        raise ValueError("Expected an absolute regular retained file: " + str(path))
    resolved = path.resolve(strict=True)
    if not resolved.is_relative_to(root) or not resolved.is_file():
        raise ValueError("File escapes retained archive or is not regular: " + str(path))
    return resolved


def finalize(root):
    """Validate all cache records, then canonicalize only archived metadata."""
    root = Path(root).resolve(strict=True)
    records = []
    for path in sorted(root.rglob("*.json")):
        raw = path.read_bytes()
        try:
            metadata = json.loads(raw, parse_constant=reject_constant)
        except ValueError:
            # A malformed file cannot be classified by its decoded keys. Fail
            # closed instead of silently overlooking an escaped cache key.
            raise ValueError("Malformed retained JSON: " + str(path)) from None
        if not isinstance(metadata, dict) or "outputLastModificationTime" not in metadata:
            continue
        retained_file(path, root)
        metadata = json.loads(raw, object_pairs_hook=unique_object, parse_constant=reject_constant)
        required = {
            "cacheVersion": str, "outputFile": str,
            "outputLastModificationTime": str, "compile": list,
            "link": list, "linkcmd": str,
        }
        if any(not isinstance(metadata.get(key), kind) for key, kind in required.items()):
            raise ValueError("Invalid Nim build-cache schema: " + str(path))
        output = retained_file(Path(metadata["outputFile"]), root)
        timestamp = metadata["outputLastModificationTime"]
        fields = list(TIMESTAMP_FIELD.finditer(raw))
        if len(fields) != 1 or json.loads(fields[0][1]) != timestamp:
            raise ValueError("Ambiguous cache timestamp spelling: " + str(path))
        replacement = raw
        if timestamp:
            if not re.fullmatch(r"\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d[+-]\d\d:\d\d", timestamp):
                raise ValueError("Unsupported cache timestamp: " + str(path))
            actual = int(output.stat().st_mtime)
            if int(datetime.fromisoformat(timestamp).timestamp()) != actual:
                raise ValueError("Cache timestamp disagrees with retained output: " + str(path))
            start, end = fields[0].span(1)
            replacement = raw[:start] + json.dumps(TIMESTAMP).encode() + raw[end:]
        records.append((path, output, timestamp, replacement))
    if not records:
        raise ValueError("No retained Nim build-cache records found")

    # Validate the complete tree before mutating any file. In particular a bad
    # later record must not turn an earlier timestamp into apparently good data.
    outputs = {output for _, output, _, _ in records}
    receipt = (
        "Nim package-check retained archive format 1\n"
        "Output mtimes and recorded cache timestamps use the Nix store epoch.\n"
        "Canonical archive timestamps are not wall-clock execution provenance.\n"
        "All other cache bytes and all compiler/source/command/log contents are retained.\n"
        f"epoch={EPOCH}\ncache-records={len(records)}\noutputs={len(outputs)}\n"
        f"timestamp-records={sum(bool(timestamp) for _, _, timestamp, _ in records)}\n"
    )
    for path, output, timestamp, _ in records:
        receipt += (
            f"cache={json.dumps(str(path.relative_to(root)))} "
            f"output={json.dumps(str(output.relative_to(root)))} "
            f"timestamp={'canonical' if timestamp else 'not-recorded'}\n"
        )
    policy = root / POLICY
    if policy.exists() or policy.is_symlink():
        retained_file(policy, root)
        if policy.read_text() != receipt:
            raise ValueError("Refusing to overwrite a different archive policy receipt")
    for output in outputs:
        os.utime(output, (EPOCH, EPOCH))
    for path, _, _, replacement in records:
        if path.read_bytes() != replacement:
            path.write_bytes(replacement)
    policy.write_text(receipt)
    return len(records)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    print(f"Retained {finalize(args.output)} canonical Nim build-cache records")
