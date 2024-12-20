# MDict MDX/MDD Maker

- Convert to Octopus MDict MDX/MDD any dictionary supported for reading by [pyglossary](https://github.com/ilius/pyglossary?tab=readme-ov-file#supported-formats), such as AARD2 .SLOB, Lingvo .DSL, Stardict .IFO, CSV, SQL etc. Handles and packs to `.MDD` associated resources, such as CSS, JS, JPG, PNG, MP3 files, etc.

## Requirements
- bash-like shell
  
| Tool | Install command |
| ------------- | ------------- |
| [pyglossary](https://github.com/ilius/pyglossary) | `pip3 install pyglossary` |
| [mdict-utils](https://github.com/liuyug/mdict-utils) | `pip3 install mdict-utils` |
| [sqlite3](https://www.sqlite.org/download.html) | already present on linux |

## Usage examples

```bash
# ABBYY Lingvo DSL format (auto-detects packed resources in `*.files.zip`)
mdict-maker.sh ldoce6.dsl

# Babylong BGL
mdict-maker.sh britannica_concise_encyclopedi.bgl

# ZIM (e.g. any file from https://library.kiwix.org/)
mdict-maker.sh apple.stackexchange.com_en_all_2024-10.zim

# AARD2 .slob (see https://github.com/itkach/slob/wiki/Dictionaries https://ftp.halifax.rwth-aachen.de/aarddict/ https://groups.google.com/g/aarddict)
mdict-maker.sh eswiki20231201-vol-01.slob

```


