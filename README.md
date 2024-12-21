# MDict MDX/MDD Maker

- Convert to Octopus MDict MDX/MDD any dictionary supported for reading by [pyglossary](https://github.com/ilius/pyglossary?tab=readme-ov-file#supported-formats), such as AARD2 .SLOB, Lingvo .DSL, Stardict .IFO, CSV, SQL etc. Handles and packs to `.MDD` associated resources, such as CSS, JS, JPG, PNG, MP3 files, etc.

## Requirements
- bash-like shell
  
| Tool | Install command |
| ------------- | ------------- |
| [pyglossary](https://github.com/ilius/pyglossary) | `pip3 install pyglossary` |
| [mdict-utils](https://github.com/liuyug/mdict-utils) | `pip3 install mdict-utils` |
| [sqlite3](https://www.sqlite.org/download.html) | already present on linux |
| unzip, iconv, file | preinstalled on linux<br>on window use [WSL](https://learn.microsoft.com/en-us/windows/wsl/install), [msys](https://www.msys2.org/), [cygwin](https://www.cygwin.com/), [cmder](https://cmder.app/), etc |

## Pyglossary dependencies

Converting to and from specific formats with pyglossary requires installation of additional python modules.

For example, for converting to and from AARD2 .slob `pyicu` and `python-lzo` will be needed. To convert ZIM files from [library.kiwix.org](https://library.kiwix.org/) `libzim` needs to be installed, etc.

To install _all_ modules:

```bash
python3 -m pip install pymorphy2 lxml polib PyYAML beautifulsoup4 html5lib PyICU python-lzo python-idzip marisa-trie libzim mistune xxhash
```

Installing `pyicu` and `python-lzo` from source requires development tools such as xcode on macos, `build-essential` on linux, or msvscompiler/mingw on windows. For some operating systems it might be possible to install precompiled versions using the following commands:

```bash
pip install --extra-index-url https://glowinthedark.github.io/python-lzo/ --index-strategy unsafe-best-match python-lzo
pip install --extra-index-url https://glowinthedark.github.io/pyicu-build --index-strategy unsafe-best-match pyicu
```

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


