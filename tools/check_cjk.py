#!/usr/bin/env python3
"""Fail when a tracked text file contains CJK characters.

This fork is English-only: UI strings, docs, comments and the changelog. The
single exception is the upstream copyright holder's name in LICENSE, which is a
legal notice and must not be edited.

    python3 tools/check_cjk.py
"""
import pathlib
import re
import subprocess
import sys

# Han, Hiragana, Katakana, Hangul, CJK punctuation and fullwidth forms.
CJK = re.compile(r"[\u2e80-\u9fff\u3000-\u303f\uff00-\uffef\uac00-\ud7af]")

# LICENSE: the copyright line names the upstream author in Chinese.
EXEMPT = {"LICENSE"}

BINARY_SUFFIXES = {
    ".icns", ".pth", ".onnx", ".bin", ".wav", ".mp3", ".ogg", ".flac",
    ".png", ".jpg", ".jpeg", ".gif", ".zip", ".dmg",
}


def main() -> int:
    tracked = subprocess.run(
        ["git", "ls-files", "-z"], capture_output=True, check=True
    ).stdout.split(b"\0")
    bad: list[str] = []
    for raw in tracked:
        if not raw:
            continue
        path = pathlib.Path(raw.decode())
        if str(path) in EXEMPT or path.suffix.lower() in BINARY_SUFFIXES:
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue  # not text; nothing to enforce
        for number, line in enumerate(text.splitlines(), 1):
            if CJK.search(line):
                bad.append(f"{path}:{number}: {line.strip()[:120]}")

    if bad:
        print(
            "CJK text found. The repository is English-only "
            "(LICENSE is the only exemption):",
            file=sys.stderr,
        )
        print("\n".join(bad), file=sys.stderr)
        return 1

    print("no CJK text in tracked files")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
