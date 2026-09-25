#!/usr/bin/env python3
# PEP 723 inline metadata: `uv run` installs these into a cached, isolated env, no local install needed.
# Kept to wheel-only deps; PyICU/python-lzo (slob) and libzim (zim) are added per run with `--with`.
# /// script
# requires-python = ">=3.12"
# dependencies = ["pyglossary", "mdict-utils", "tqdm", "lxml", "beautifulsoup4"]
# ///
"""Convert any pyglossary-readable dictionary (DSL, SLOB, StarDict, BGL, ZIM, CSV…) to Octopus MDict MDX + MDD.

Output <name>.mdx (+ <name>.mdd for resources) goes to the current directory.

usage:
  mdict-maker.py ldoce6.dsl                    # after: pip3 install "pyglossary[all]" mdict-utils
  uv run mdict-maker.py ldoce6.dsl x.bgl       # deps from the inline metadata, nothing installed locally
  uv run --with PyICU --with python-lzo mdict-maker.py wiki.slob
  uv run --with libzim mdict-maker.py apple.stackexchange.com_en_all_2024-10.zim
  uv run https://raw.githubusercontent.com/glowinthedark/mdict-mdx-maker/master/mdict-maker.py x.dsl

https://github.com/glowinthedark/mdict-mdx-maker
"""

import argparse
import codecs
import html
import re
import sqlite3
import sys
import tempfile
import zipfile
from contextlib import nullcontext
from functools import cache, partial
from pathlib import Path

try:
    from mdict_utils import writer as mdict
    from pyglossary.glossary_v2 import Error, Glossary
    from tqdm import tqdm
except ModuleNotFoundError as ex:
    pkg = {"mdict_utils": "mdict-utils"}.get(root := (ex.name or "").partition(".")[0], root)
    sys.exit(
        f"Missing python module {ex.name!r} (package {pkg!r}) for {sys.executable}\n"
        f'install:  {sys.executable} -m pip install -U "pyglossary[all]" mdict-utils\n'
        f"or run without installing:  uv run {sys.argv[0]} ..."
    )

CREDIT = '<br>created with <a href="https://github.com/glowinthedark/mdict-mdx-maker">mdict-maker</a>'
COMPRESSED = {".dz", ".gz", ".bz2", ".xz", ".lzma", ".zst"}
# table/column names and the per-record SIZE (in the writer's encoding, incl. the NUL terminator)
# are dictated by mdict_utils.writer.get_record_null, which fetches each record lazily by rowid
# MDict plays audio only via sound:// links: DSL reader emits <object type="audio/…" data=…>,
# MDict/other readers emit <audio src=…>
AUDIO = re.compile(r'<object type="audio/[^"]*" data="([^"]+)".*?</object>|<audio\b[^>]*?\ssrc="([^"]+)".*?</audio>', re.S)
PACKS = {"mdx": "length(CAST(paraphrase AS BLOB)) + 1", "mdd": "length(file)"}


def res_key(name: str) -> str:
    return "\\" + name.replace("/", "\\").lstrip("\\")


@cache
def xdxf():  # lazy: lxml is optional and only needed for XDXF definitions
    try:
        from pyglossary.xdxf.py_transform import XdxfTransformer
    except ModuleNotFoundError as ex:
        sys.exit(f"XDXF definitions need python module {ex.name!r}: {sys.executable} -m pip install lxml")
    return XdxfTransformer(encoding="utf-8")


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("inputs", nargs="+", type=Path, metavar="dictionary", help="e.g. ldoce6.dsl.dz wiki.slob x.ifo")
    Glossary.init()

    for src in ap.parse_args().inputs:
        stem = Path(src.stem if src.suffix.lower() in COMPRESSED else src.name).stem  # x.dsl.dz -> x
        # stage next to the outputs (not in a possibly RAM-backed /tmp); atomic rename on success
        with tempfile.TemporaryDirectory(prefix=f".{stem}-", dir=".") as tmp:
            db = str(Path(tmp, "stage.db"))
            # seed mdict_utils' connection cache so the random-access record fetches during packing
            # go through one mmap'ed connection instead of a fresh, cold one
            con = mdict.MDICT_OBJ[db] = sqlite3.connect(db)
            try:
                con.executescript("""
                    PRAGMA journal_mode = OFF; PRAGMA synchronous = OFF; PRAGMA mmap_size = 1099511627776;
                    CREATE TABLE mdx (entry TEXT NOT NULL, paraphrase TEXT NOT NULL);
                    CREATE TABLE mdd (entry TEXT PRIMARY KEY, file BLOB NOT NULL);
                """)

                glos = Glossary()
                try:
                    glos.directRead(str(src))
                    for e in tqdm(glos, desc=src.name, unit=" entries"):
                        if e.isData():
                            con.execute("INSERT OR IGNORE INTO mdd VALUES (?, ?)", (res_key(e.s_term), e.data))
                            continue
                        defi = e.defi
                        match e.detectDefiFormat():
                            case "m" if "\n" in defi:
                                defi = f"<pre>{defi}</pre>"
                            case "x":
                                defi = xdxf().transformByInnerString(defi)
                        defi = defi.replace("bword://", "entry://")
                        if "audio" in defi:
                            defi = AUDIO.sub(lambda m: f'<a href="sound://{m[1] or m[2]}">🔊</a>', defi)
                        term, *alts = e.l_term
                        con.execute("INSERT INTO mdx VALUES (?, ?)", (term, defi))
                        con.executemany("INSERT INTO mdx VALUES (?, ?)", ((a, f"@@@LINK={term}") for a in alts if a != term))
                    title, info = glos.getInfo("name") or stem, glos.getInfo("description")
                except Error as ex:
                    sys.exit(f"{src}: {ex}")
                finally:
                    glos.cleanup()
                if not con.execute("SELECT 1 FROM mdx LIMIT 1").fetchone():
                    sys.exit(f"{src}: no entries read")

                # Lingvo/GoldenDict resources: archives (x.files.zip, x.dsl.files.zip, x.dsl.dz.files.zip…)
                # or unpacked dirs (x.dsl.files/); skip what pyglossary already yielded (<input>.files.zip)
                for res in sorted(
                    p for p in src.parent.iterdir() if p.name.startswith(f"{stem}.")
                    and (p.is_dir() if p.name.endswith("files") else p.name.endswith("files.zip") and p.is_file())
                ):
                    print(f"Adding resources: {res}")
                    have = {k for (k,) in con.execute("SELECT entry FROM mdd")}
                    with zipfile.ZipFile(res) if res.is_file() else nullcontext() as zf:
                        members = (
                            {res_key(i.filename): partial(zf.read, i) for i in zf.infolist() if not i.is_dir()} if zf else
                            {res_key(f.relative_to(res).as_posix()): f.read_bytes for f in res.rglob("[!.]*") if f.is_file()}
                        )
                        con.executemany("INSERT OR IGNORE INTO mdd VALUES (?, ?)", ((k, read()) for k, read in members.items() if k not in have))
                con.commit()

                desc = "<br>".join(filter(None, (title, info if (info or "").strip() != title.strip() else None))) + CREDIT
                if (ann := src.with_name(f"{stem}.ann")).is_file():  # Lingvo annotation, usually UTF-16 with BOM
                    raw = ann.read_bytes()
                    enc = "utf-16" if raw[:2] in (codecs.BOM_UTF16_LE, codecs.BOM_UTF16_BE) else "utf-8-sig"
                    desc += f"<pre>{html.escape(raw.decode(enc, 'replace').strip())}</pre>"

                for ext, size in PACKS.items():
                    items = [
                        {"key": k, "size": n, "pos": rowid, "path": db}
                        for k, n, rowid in con.execute(f"SELECT entry, {size}, rowid FROM {ext}")
                    ]
                    if not items:
                        print(f"No resources: skipping {stem}.{ext}")
                        continue
                    out = Path(tmp, f"{stem}.{ext}")
                    mdict.pack(str(out), items, title, desc, is_mdd=ext == "mdd")
                    print(f"Created {out.replace(out.name).resolve()}")
            finally:
                mdict.MDICT_OBJ.pop(db, con).close()


if __name__ == "__main__":
    main()
