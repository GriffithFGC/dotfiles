#!/usr/bin/env python3
# Personal (fork GriffithFGC): translation backend of the perso-translate bubble.
# Reads TR_TEXT, picks the direction (Japanese -> English, anything else ->
# Japanese), asks translate-shell for Google's raw answer and prints one JSON
# object: {"src", "dst", "text", "reading"}. "reading" is the romaji of the
# Japanese side so kana / kanji can be read back.
import json
import os
import re
import subprocess
import sys

JAPANESE = re.compile(r"[぀-ヿ㐀-䶿一-鿿ｦ-ﾟ]")


def main():
    text = os.environ.get("TR_TEXT", "").strip()
    if not text:
        return {"error": "empty"}
    src, dst = ("ja", "en") if JAPANESE.search(text) else ("auto", "ja")

    out = subprocess.run(["trans", "-dump", "-no-auto", f"{src if src != 'auto' else ''}:{dst}", text],
                         capture_output=True, text=True, timeout=12).stdout
    # -dump prints the raw response: a length line, then a JSON array
    start = out.find("[")
    data, _ = json.JSONDecoder().raw_decode(out[start:]) if start >= 0 else (None, 0)
    if not data or not data[0]:
        return {"error": "failed"}

    segments = data[0]
    translated = "".join(s[0] for s in segments if s and isinstance(s[0], str)).strip()
    # The last segment holds transliterations: [_, _, translation's, source's?]
    translit = segments[-1] if segments[-1] and segments[-1][0] is None else []
    idx = 2 if dst == "ja" else 3
    reading = translit[idx] if len(translit) > idx and isinstance(translit[idx], str) else ""
    if src == "auto" and len(data) > 2 and isinstance(data[2], str):
        src = data[2]
    if not translated:
        return {"error": "failed"}
    return {"src": src, "dst": dst, "text": translated, "reading": reading or ""}


try:
    result = main()
except Exception as e:  # network, timeout, unexpected answer
    result = {"error": "failed", "detail": str(e)}
print(json.dumps(result, ensure_ascii=False))
sys.exit(0)
