# MDX Maker

- Convert to Octopus MDict MDX/MDD any dictionary supported for reading by [pyglossary](https://github.com/ilius/pyglossary?tab=readme-ov-file#supported-formats), e.g. from AARD2 .SLOB, Lingvo .DSL, Stardict .IFO

## Requirements
- bash-like shell
  
| Tool | Install command |
| ------------- | ------------- |
| [pyglossary](https://github.com/ilius/pyglossary) | `pip3 install pyglossary` |
| [mdict-utils](https://github.com/liuyug/mdict-utils) | `pip3 install mdict-utils` |
| [sqlite3](https://www.sqlite.org/download.html) | already present on linux |

## Usage

```bash
mdx-maker.sh ldoce6.dsl
```
