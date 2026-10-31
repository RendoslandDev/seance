#!/usr/bin/env python3
"""Build assets/data/bible/<id>.json from eBible.org's public-domain VPL texts.

    curl -sL https://ebible.org/Scriptures/eng-kjv_vpl.zip  -o kjv.zip  # KJV (1769)
    curl -sL https://ebible.org/Scriptures/engwebp_vpl.zip  -o web.zip  # World English Bible
    unzip kjv.zip -d kjv && unzip web.zip -d web
    python3 tool/build_bible.py kjv/eng-kjv_vpl.txt kjv "King James Version" assets/data/bible/kjv.json
    python3 tool/build_bible.py web/engwebp_vpl.txt web "World English Bible" assets/data/bible/web.json

Output: {"id", "name", "books": [{"code", "name", "chapters": [[verse, ...], ...]}]}
Only the 66 books of the Protestant canon are kept, in canonical order.
"""

import json
import re
import sys
from pathlib import Path

BOOKS = [
    ("GEN", "Genesis"), ("EXO", "Exodus"), ("LEV", "Leviticus"),
    ("NUM", "Numbers"), ("DEU", "Deuteronomy"), ("JOS", "Joshua"),
    ("JDG", "Judges"), ("RUT", "Ruth"), ("1SA", "1 Samuel"),
    ("2SA", "2 Samuel"), ("1KI", "1 Kings"), ("2KI", "2 Kings"),
    ("1CH", "1 Chronicles"), ("2CH", "2 Chronicles"), ("EZR", "Ezra"),
    ("NEH", "Nehemiah"), ("EST", "Esther"), ("JOB", "Job"),
    ("PSA", "Psalms"), ("PRO", "Proverbs"), ("ECC", "Ecclesiastes"),
    ("SOL", "Song of Solomon"), ("ISA", "Isaiah"), ("JER", "Jeremiah"),
    ("LAM", "Lamentations"), ("EZE", "Ezekiel"), ("DAN", "Daniel"),
    ("HOS", "Hosea"), ("JOE", "Joel"), ("AMO", "Amos"), ("OBA", "Obadiah"),
    ("JON", "Jonah"), ("MIC", "Micah"), ("NAH", "Nahum"),
    ("HAB", "Habakkuk"), ("ZEP", "Zephaniah"), ("HAG", "Haggai"),
    ("ZEC", "Zechariah"), ("MAL", "Malachi"),
    ("MAT", "Matthew"), ("MAR", "Mark"), ("LUK", "Luke"), ("JOH", "John"),
    ("ACT", "Acts"), ("ROM", "Romans"), ("1CO", "1 Corinthians"),
    ("2CO", "2 Corinthians"), ("GAL", "Galatians"), ("EPH", "Ephesians"),
    ("PHI", "Philippians"), ("COL", "Colossians"),
    ("1TH", "1 Thessalonians"), ("2TH", "2 Thessalonians"),
    ("1TI", "1 Timothy"), ("2TI", "2 Timothy"), ("TIT", "Titus"),
    ("PHM", "Philemon"), ("HEB", "Hebrews"), ("JAM", "James"),
    ("1PE", "1 Peter"), ("2PE", "2 Peter"), ("1JO", "1 John"),
    ("2JO", "2 John"), ("3JO", "3 John"), ("JUD", "Jude"),
    ("REV", "Revelation"),
]

LINE = re.compile(r"^(\w{3}) (\d+):(\d+) (.*)$")


def clean(text: str) -> str:
    text = re.sub(r"[\[\]]", "", text)  # KJV marks supplied words as [was]
    text = text.replace("¶", "")  # KJV paragraph marks
    return re.sub(r"\s+", " ", text).strip()


def main(src: str, tid: str, name: str, out: str) -> None:
    verses: dict[str, dict[int, dict[int, str]]] = {}
    for line in Path(src).read_text(encoding="utf-8-sig").splitlines():
        m = LINE.match(line)
        if not m:
            continue
        code, ch, vs, text = m.group(1), int(m.group(2)), int(m.group(3)), m.group(4)
        verses.setdefault(code, {}).setdefault(ch, {})[vs] = clean(text)

    books = []
    gaps = []
    for code, title in BOOKS:
        chapters = verses[code]
        out_chapters = []
        for ch in range(1, max(chapters) + 1):
            vs = chapters.get(ch, {})
            last = max(vs) if vs else 0
            row = []
            for v in range(1, last + 1):
                if v not in vs or not vs[v]:
                    gaps.append(f"{code} {ch}:{v}")
                row.append(vs.get(v, ""))  # keep numbering even if a verse is absent
            out_chapters.append(row)
        books.append({"code": code, "name": title, "chapters": out_chapters})

    data = {"id": tid, "name": name, "books": books}
    Path(out).parent.mkdir(parents=True, exist_ok=True)
    Path(out).write_text(json.dumps(data, ensure_ascii=False, separators=(",", ":")))
    total = sum(len(c) for b in books for c in b["chapters"])
    print(f"{name}: {len(books)} books, {total} verses -> {out}")
    if gaps:
        print(f"  {len(gaps)} absent verses (text-critical omissions): {gaps[:12]}")


if __name__ == "__main__":
    main(*sys.argv[1:5])
