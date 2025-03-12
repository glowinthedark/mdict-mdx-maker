#!/bin/bash

# MDict MDX/MDD Maker v 0.13
# https://github.com/glowinthedark/mdict-mdx-maker, glwnd2030@gmail.com, 2025

# Convert to Octopus MDict MDX/MDD from AARD2 .SLOB, Lingvo .DSL, Stardict .IFO,
# requirements:
#   - pyglossary
#   - mdict-utils
#   - sqlite3
#   - unzip
#set -x
# set -e

checktool() {
    command -v "$1" 2>/dev/null || { echo -n "ERROR: $1 not found! $2 " >&2; exit 1; }
}

echo "Check required tools..."
checktool pyglossary "Install with: 'pip3 install pyglossary'"
checktool mdict "Install with: 'pip3 install mdict-utils'"
checktool sqlite3 "Install with OS package manager, e.g. 'apt install sqlite3'"
checktool unzip "[dsl] Install with OS package manager, e.g. 'apt install unzip'"
checktool iconv "[dsl] Install with OS package manager, ootb on linux"
checktool file "[dsl] Install with OS package manager, ootb on linux"

if [[ "z" == "z$1" ]]; then
    printf '\n  USAGE: %s dictionary.dsl\n\n' "$(basename "$0")"
    exit 1
fi

input_file="$1"
input_file_no_ext="${1%%.*}" # strip extension
input_file_basename="$(basename "$1")"
db_file="${input_file_basename%.*}.db"
csv_file="${input_file_basename%.*}.csv"
res_dir="${csv_file}_res"
mdx_file="${input_file_basename%.*}.mdx"
mdd_file="${input_file_basename%.*}.mdd"

rm -rf title.html description.html

if [ -e "$db_file" ]; then
    #read -p "$db_file already exists! OVERWRITE? (y/n) " answer
    #if [[ $answer =~ ^[Yy]$ ]]; then
    "$db_file already exists! OVERWRITING..."
    rm -v "$db_file"
    #fi
fi

pyglossary --cmd "$input_file" "$db_file" --write-format=AyanDictSQLite

# Connect to the SQLite3 database
sqlite3 "$db_file" <<EOF
-- Step 1: Rename columns in the 'entry' table
ALTER TABLE entry RENAME COLUMN term TO entry;
ALTER TABLE entry RENAME COLUMN article TO paraphrase;

-- Step 2: Rename the 'entry' table to 'mdx'
ALTER TABLE entry RENAME TO mdx;

-- Step 3: Drop the 'alt' and 'fuzzy3' tables
DROP TABLE IF EXISTS alt;
DROP TABLE IF EXISTS fuzzy3;

-- Step 4: Rename the 'name' column in the 'meta' table to 'title'
UPDATE meta SET key = 'title' WHERE key = 'name';
EOF

sqlite3 "$db_file" ".output title.html" "SELECT value FROM meta WHERE key = 'title';"
cp title.html description.html
echo '<br>created with <a href="https://github.com/glowinthedark/mdict-mdx-maker">mdict-maker</a>' >> description.html

# for DSL/DZ check for .ann description
if [[ "${input_file}" =~ .(dz|dsl)$ ]]; then
  ann_file="${input_file_no_ext}.ann"

  if [[ -f "${ann_file}" ]]; then
    echo "Found DSL description file: ${ann_file}"
    echo '<pre>' >> description.html

    # recode utf16le to utf8 if detected
    if [[ $(file --mime-encoding -b "${ann_file}") = 'utf-16le' ]]; then
      iconv -f utf-16le -t utf-8 "${ann_file}" >> description.html
    else
      cat "${ann_file}" >> description.html
    fi
    echo '</pre>' >> description.html
  fi
fi

mdict --db-txt "$db_file"
mdict --title title.html --description description.html -a "$db_file".txt "${mdx_file}"

echo "Created MDX file: ${mdx_file}"
echo 'Checking for MDD resources...'

# extract resources in Csv mode and create MDD (skip for DSL/DZ)
if [[ ! "${input_file}" =~ .(dz|dsl)$ ]]; then
  pyglossary --cmd "${input_file}" "${csv_file}" --write-format=Csv
fi

if [[ ! -d "${res_dir}" ]]; then
    # check for xyz.files.zip resources and unpack them
    for zip_res_file in "${input_file_no_ext}"*files.zip ; do
      echo "Processing file: $zip_res_file"

      echo "Unpacking ${zip_res_file} to: ${res_dir}... Please wait..."
      unzip -q "$zip_res_file" -d "${res_dir}"
    done
fi

if [[ -d "${res_dir}" ]]; then
    echo "Media files detected!"
    mdict --title title.html --description description.html -a "${res_dir}" "${mdd_file}"
else
    echo "No media files found! Skip creating MDD."
fi

echo 'All done!'

#if [[ "$2" == "-y" || "$(read -r -p 'Remove intermediary files? (y/n) ' answer && echo "$answer")" =~ ^[Yy]$ ]]; then
  rm -vrf "$db_file" "${csv_file}" "${db_file}.txt" title.html description.html "$res_dir"
#fi
