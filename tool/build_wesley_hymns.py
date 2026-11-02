#!/usr/bin/env python3
"""Build assets/data/wesley_1876.json from the CCEL public-domain edition of
John Wesley's "A Collection of Hymns for the Use of the People Called
Methodists" (1876 edition, 1,026 hymns).

Source: https://ccel.org/ccel/wesley/hymn/files/hymn.html
The electronic editor released it as a Public Domain edition
(see https://ccel.org/ccel/wesley/hymn/files/jwg4000.html).

Usage:
    # 1. download the contents page and every hymn page
    curl -sL https://ccel.org/ccel/wesley/hymn/files/hymn.html -o SRC/hymn.html
    # each jwgNN/jwgNNNN.html linked from it  ->  SRC/pages/jwgNNNN.html
    # 2. convert
    python3 tool/build_wesley_hymns.py SRC assets/data/wesley_1876.json
"""

import html
import json
import re
import sys
from pathlib import Path


def read(path: Path) -> str:
    raw = path.read_bytes()
    try:
        return raw.decode("utf-8")
    except UnicodeDecodeError:
        return raw.decode("cp1252", errors="replace")


def text(fragment: str) -> str:
    fragment = re.sub(r"(?i)<br\s*/?>", "\n", fragment)
    fragment = re.sub(r"<[^>]+>", "", fragment)
    fragment = html.unescape(fragment).replace("\r", "")
    lines = [re.sub(r"[ \t]+", " ", l).strip() for l in fragment.split("\n")]
    return "\n".join(l for l in lines if l)


def sentence_case_opening(line: str) -> str:
    """'O FOR a thousand tongues' -> 'O for a thousand tongues'."""
    words = line.split(" ")
    out = []
    for i, w in enumerate(words):
        letters = re.sub(r"[^A-Za-z]", "", w)
        if len(letters) > 1 and letters.isupper() and i < 3:
            w = w[0] + w[1:].lower() if i == 0 else w.lower()
            if letters in ("LORD", "GOD", "JESUS", "CHRIST"):
                w = w.capitalize()
        out.append(w)
    return " ".join(out)


def parse_sections(contents_html: str):
    """[(first hymn number, part, section title)] from the contents page."""
    start = contents_html.find('NAME="contents"')
    end = contents_html.find('NAME="preface"')
    block = contents_html[start:end]
    sections = []
    part = ""
    for chunk in re.split(r"(?i)<P>", block):
        plain = re.sub(r"\s+", " ", text(chunk)).strip()
        m_part = re.match(r"(PART [IVX]+\.?.*?|SUPPLEMENT\.?)(?=\s*SECTION|$)", plain)
        if m_part:
            part = m_part.group(1).strip().rstrip(".").title()
            part = re.sub(r"\b([IVX][ivx]*)\b", lambda m: m.group(1).upper(), part)
        link = re.search(r'(?i)href\s*=\s*"#h(\d+)"\s*>(.*?)</a>', chunk, re.S)
        if not link:
            continue
        number = int(link.group(1))
        title = re.sub(r"\s+", " ", text(link.group(2))).strip().rstrip(".")
        sections.append((number, part, title))
    return sections


_COUNT = r"\d+s?(?:\s?-\s?\d+s?)?"
_SYLLABLES = r"\d+(?:,?\s?\d+)+"  # e.g. "5 5 9, 5 5 9"
METER = re.compile(
    r"^((?:[CLSPH]\.\s?M\.?"
    r"|" + _SYLLABLES +
    r"|" + _COUNT + r"(?:\s?&\s?" + _COUNT + r")*)"
    r"(?:\.?\s*\d(?:st|nd|rd|th)\.?\s*metre\.?)?)"
    r"(?=[\s.]|$)\s*(.*)$",
    re.S,
)


def split_heading(heading: str, number: int):
    """'L.M. Luke xiv. 16 - 24' -> ('L.M.', 'Luke xiv. 16-24')."""
    heading = re.sub(r"\s+", " ", heading).strip()
    heading = re.sub(rf"^{number}\s+", "", heading)  # stray hymn number
    heading = re.sub(r"(\d)O", r"\g<1>0", heading)  # OCR: '1Os' -> '10s'
    m = METER.match(heading)
    if not m or re.fullmatch(r"\d+", m.group(1).strip()):  # e.g. "1 Kings"
        return None, heading or None
    meter = re.sub(r"\s*-\s*", "-", m.group(1).strip()).rstrip(".")
    meter = re.sub(r"\.?\s*(\d(?:st|nd|rd|th))\.?\s*metre", r", \1 metre", meter)
    if re.fullmatch(_SYLLABLES, meter):
        meter = re.sub(r"\s*,\s*", ", ", meter)
    if re.match(r"^[CLSPH]\.\s?M$", meter):
        meter = meter.replace(" ", "") + "."
    note = m.group(2).strip().lstrip(".-–— ").strip()
    note = re.sub(r"\s+-\s+", "–", note)
    if note.rstrip(".") == meter:  # heading repeats the meter
        note = ""
    return meter, note or None


def parse_hymn(number: int, page: str):
    body = page[page.lower().find("<body") :]
    meter_m = re.search(r"(?is)<H3>(.*?)</H3>", body)
    meter, note = split_heading(text(meter_m.group(1)), number) if meter_m else (None, None)
    verses = []
    chunks = re.split(r"(?i)<P>", body)[1:]
    if not chunks:
        # Some pages omit <P>: stanzas end at a line without a trailing <BR>.
        rest = re.sub(r"(?is)^.*?</H3>", "", body)
        rest = re.sub(r"(?is)</BODY>.*$", "", rest)
        stanza, chunks = [], []
        for line in rest.split("\n"):
            if not line.strip():
                continue
            stanza.append(line)
            if not re.search(r"(?i)<br\s*/?>\s*$", line):
                chunks.append("\n".join(stanza))
                stanza = []
        if stanza:
            chunks.append("\n".join(stanza))
    for chunk in chunks:
        chunk = re.sub(r"(?is)<H\d>.*?</H\d>", "", chunk)
        v = text(chunk)
        if not v:
            continue
        v = re.sub(r"^\d+\s+", "", v)  # leading verse number
        verses.append(v)
    if not verses:
        return None
    verses[0] = sentence_case_opening(verses[0])
    first_line = verses[0].split("\n")[0].rstrip(",;:.!—-")
    return {
        "number": number,
        "firstLine": first_line,
        "meter": meter,
        "note": note,
        "verses": verses,
    }


def main(src: str, out: str) -> None:
    src_dir = Path(src)
    sections = parse_sections(read(src_dir / "hymn.html"))
    patches = json.loads(
        (Path(__file__).parent / "wesley_1876_patches.json").read_text()
    )
    patched = {h["number"]: h for h in patches["hymns"]}
    hymns = []
    missing = []
    for n in range(1, 1027):
        if n in patched:  # CCEL serves these pages empty
            hymns.append(patched[n])
            continue
        page = src_dir / "pages" / f"jwg{n:04d}.html"
        if not page.exists():
            missing.append(n)
            continue
        h = parse_hymn(n, read(page))
        if h is None:
            missing.append(n)
            continue
        hymns.append(h)
    data = {
        "book": {
            "id": "wesley1876",
            "title": "A Collection of Hymns for the Use of the People Called Methodists",
            "shortTitle": "Wesley’s Hymns",
            "editor": "John Wesley",
            "edition": "1876 edition, with Supplement",
            "source": "Christian Classics Ethereal Library (public domain edition)",
            "sourceUrl": "https://ccel.org/ccel/wesley/hymn",
        },
        "sections": [
            {"start": n, "part": p, "title": t} for (n, p, t) in sections
        ],
        "hymns": hymns,
    }
    Path(out).write_text(json.dumps(data, ensure_ascii=False, separators=(",", ":")))
    print(f"{len(hymns)} hymns, {len(sections)} sections -> {out}")
    if missing:
        print(f"missing/empty: {missing}", file=sys.stderr)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
