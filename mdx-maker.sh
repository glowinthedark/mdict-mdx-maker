#!/bin/bash

# SOURCE: https://github.com/glowinthedark/mdx-maker, glwnd2030@gmail.com

# Convert to Octopus MDict MDX/MDD from AARD2 .SLOB, Lingvo .DSL, Stardict .IFO, 
# requirements:
#   - pyglossary
#   - mdict-utils
#   - sqlite3

#set -x
set -e

checktool() {
    command -v "$1" 2>/dev/null || { echo -n "ERROR: $1 not found! $2 " >&2; exit 1; }
}

checktool pyglossary "Install with: 'pip3 install pyglossary'"
checktool mdict "Install with: 'pip3 install mdict-utils'"
checktool sqlite3 "Install with OS package manager, e.g. 'apt install sqlite3'"

if [[ "z" == "z$1" ]]; then
    printf '\n\tUSAGE: %s dictionary.dsl\n' "$0"
    exit 1
fi

input_file="$1"

if [[ "$input_file" =~ .*\.dz ]]; then
    echo 'Unpacking .dz file...'
    dictzip -k -d "$1"
    input_file="${1%.*}"
fi

db_file="${input_file%.*}.db"
csv_file="${input_file%.*}.csv"
res_dir="${csv_file}_res"
mdx_file="${input_file%.*}.mdx"
mdd_file="${input_file%.*}.mdd"

if [ -e "$db_file" ]; then
    read -p "$db_file already exists! OVERWRITE? (y/n) " answer
    if [[ $answer =~ ^[Yy]$ ]]; then
        rm -v "$db_file"
    else
        exit 1
    fi
fi

pyglossary --cmd "$input_file" "$csv_file" --write-format=Csv

# Connect to the SQLite3 database
sqlite3 "$db_file" <<EOF
-- Create tables and indexes
CREATE TABLE mdx (entry TEXT NOT NULL, paraphrase TEXT NOT NULL);
CREATE TABLE meta (key TEXT NOT NULL, value TEXT NOT NULL);
CREATE INDEX mdx_entry_index ON mdx (entry);
EOF

# create sqlite db from csv
sqlite3 "$db_file"  ".mode csv"  ".import ${csv_file} mdx" ".exit"

sqlite3 "$db_file" "INSERT INTO meta (key, value) SELECT 'title', paraphrase FROM mdx WHERE entry = '#name'; DELETE FROM mdx WHERE entry = '#name';"
sqlite3 "$db_file" "INSERT INTO meta (key, value) SELECT entry, paraphrase FROM mdx WHERE entry = '#sourceLang'; DELETE FROM mdx WHERE entry = '#sourceLang';"
sqlite3 "$db_file" "INSERT INTO meta (key, value) SELECT entry, paraphrase FROM mdx WHERE entry = '#targetLang'; DELETE FROM mdx WHERE entry = '#targetLang';"
sqlite3 "$db_file" "INSERT INTO meta (key, value) SELECT 'creationdate', paraphrase FROM mdx WHERE entry = '#creationTime'; DELETE FROM mdx WHERE entry = '#creationTime';"
sqlite3 "$db_file" "INSERT INTO meta (key, value) VALUES ('description', 'created with <a href=https://github.com/glowinthedark/mdx-maker>mdx-maker</a>');"
sqlite3 "$db_file" "INSERT INTO meta (key, value) VALUES ('format', 'Html');"

# get the title
sqlite3 "$db_file" ".output title.html" "SELECT value FROM meta WHERE key = 'title';"

cp title.html description.html

mdict --db-txt "$db_file"

mdict --title title.html --description description.html -a "$db_file".txt "${mdx_file}"

echo 'Created MDX file: ${mdx_file}'
echo 'Checking for MDD resources...'

if [[ -d "${res_dir}" ]]; then
    echo "Media files found!"
    mdict --title title.html --description description.html -a "${res_dir}" "${mdd_file}"
else
    echo "No media files found! Skipping creating MDD file."
fi

echo 'All done!'
#read -r -p "Remove intermediary files? (y/n) " answer

if [[ $answer =~ ^[Yy]$ ]]; then
    rm -v "$db_file" "${csv_file}" "${res_dir}" "${db_file}.txt" title.html description.html
fi
