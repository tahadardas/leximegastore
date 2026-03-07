#!/usr/bin/env python3
"""Fix mojibake Arabic text in PHP/Dart string literals.

This script targets common UTF-8-as-Latin1 corruption like:
  Ø§Ù„Ù…Ù†ØªØ¬ -> المنتج

Usage:
  python scripts/fix_arabic_mojibake.py --write path1 path2 ...
  python scripts/fix_arabic_mojibake.py path1 path2 ...   # dry-run
"""
from __future__ import annotations

import argparse
from pathlib import Path
import sys

SUSPICIOUS_CHARS = set("ØÙÃÂÐðâÊËÌÍÎÏÒÓÔÕÖ×ÚÛÜÝÞßœ€šŸ")
CP1252_PUNCT_TO_BYTE = {
    0x20AC: 0x80,  # €
    0x201A: 0x82,  # ‚
    0x0192: 0x83,  # ƒ
    0x201E: 0x84,  # „
    0x2026: 0x85,  # …
    0x2020: 0x86,  # †
    0x2021: 0x87,  # ‡
    0x02C6: 0x88,  # ˆ
    0x2030: 0x89,  # ‰
    0x0160: 0x8A,  # Š
    0x2039: 0x8B,  # ‹
    0x0152: 0x8C,  # Œ
    0x017D: 0x8E,  # Ž
    0x2018: 0x91,  # ‘
    0x2019: 0x92,  # ’
    0x201C: 0x93,  # “
    0x201D: 0x94,  # ”
    0x2022: 0x95,  # •
    0x2013: 0x96,  # –
    0x2014: 0x97,  # —
    0x02DC: 0x98,  # ˜
    0x2122: 0x99,  # ™
    0x0161: 0x9A,  # š
    0x203A: 0x9B,  # ›
    0x0153: 0x9C,  # œ
    0x017E: 0x9E,  # ž
    0x0178: 0x9F,  # Ÿ
}


def suspicious_score(s: str) -> int:
    return sum(ch in SUSPICIOUS_CHARS for ch in s) + s.count("�") * 2


def _decode_latin1_utf8(s: str) -> str | None:
    try:
        return s.encode("latin-1").decode("utf-8")
    except (UnicodeEncodeError, UnicodeDecodeError):
        return None


def _decode_with_cp1252_punct_map(s: str) -> str | None:
    mapped = "".join(chr(CP1252_PUNCT_TO_BYTE.get(ord(ch), ord(ch))) for ch in s)
    try:
        return mapped.encode("latin-1").decode("utf-8")
    except (UnicodeEncodeError, UnicodeDecodeError):
        return None


def maybe_fix_text(value: str) -> str:
    if suspicious_score(value) == 0:
        return value

    current = value
    for _ in range(3):
        improved = False
        for decoded in (
            _decode_latin1_utf8(current),
            _decode_with_cp1252_punct_map(current),
        ):
            if decoded is None:
                continue

            if suspicious_score(decoded) < suspicious_score(current) and "�" not in decoded:
                current = decoded
                improved = True
                break

        if not improved:
            break
    return current


def is_identifier_char(ch: str) -> bool:
    return ch.isalnum() or ch == "_"


def should_skip_dart_raw(content: str, quote_index: int) -> bool:
    # Dart raw string prefix: r'...' or r"..."
    prev = quote_index - 1
    if prev < 0:
        return False
    if content[prev] not in ("r", "R"):
        return False
    prev2 = prev - 1
    if prev2 >= 0 and is_identifier_char(content[prev2]):
        return False
    return True


def transform_content(content: str, *, is_dart: bool) -> tuple[str, int]:
    out: list[str] = []
    i = 0
    changes = 0
    n = len(content)

    while i < n:
        ch = content[i]
        if ch not in ("'", '"'):
            out.append(ch)
            i += 1
            continue

        quote = ch
        triple = i + 2 < n and content[i + 1] == quote and content[i + 2] == quote
        raw_dart = is_dart and should_skip_dart_raw(content, i)
        delim_len = 3 if triple else 1

        # Emit opening delimiter as-is.
        out.append(content[i : i + delim_len])
        i += delim_len

        literal_start = i
        escaped = False

        while i < n:
            c = content[i]
            if not raw_dart and not triple and c == "\\" and not escaped:
                escaped = True
                i += 1
                continue

            if triple:
                if c == quote and i + 2 < n and content[i + 1] == quote and content[i + 2] == quote:
                    break
            else:
                if c == quote and (raw_dart or not escaped):
                    break

            escaped = False
            i += 1

        literal = content[literal_start:i]

        fixed_literal = literal
        if not raw_dart:
            candidate = maybe_fix_text(literal)
            if candidate != literal:
                fixed_literal = candidate
                changes += 1

        out.append(fixed_literal)

        # Emit closing delimiter if present.
        if i < n:
            out.append(content[i : i + delim_len])
            i += delim_len

    return "".join(out), changes


def process_file(path: Path, write: bool) -> int:
    original = path.read_text(encoding="utf-8")
    is_dart = path.suffix.lower() == ".dart"
    updated, changes = transform_content(original, is_dart=is_dart)

    if changes > 0 and write:
        path.write_text(updated, encoding="utf-8", newline="")

    return changes


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("paths", nargs="+", help="Files to process")
    parser.add_argument("--write", action="store_true", help="Write fixes")
    args = parser.parse_args()

    total_changes = 0
    touched = 0
    for p in args.paths:
        path = Path(p)
        if not path.exists():
            print(f"[skip] missing: {path}")
            continue

        try:
            changes = process_file(path, write=args.write)
        except UnicodeDecodeError:
            print(f"[skip] non-utf8: {path}")
            continue

        if changes > 0:
            touched += 1
            total_changes += changes
            print(f"[fix] {path} ({changes} literals)")

    mode = "write" if args.write else "dry-run"
    print(f"[{mode}] files_touched={touched} literal_fixes={total_changes}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
