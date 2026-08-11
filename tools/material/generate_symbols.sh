#!/usr/bin/env bash
set -euo pipefail

revision="50f0603134ce7b70b2d71b686cc13e8b57ccb74c"
font_sha256="3500043e8929d5140f34dff8f8687e1dd5fda3a33fff20bfcc96ecd0b2f99518"
license_sha256="58d1e17ffe5109a7ae296caafcadfdbe6a7d176f0bc4ab01e12a689b0499d8bd"
codepoints_sha256="a949567431829ed6f382911f3e6d3158627a4a5027d7e6f3d89a85a55c027279"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "${script_dir}/../.." && pwd)"
work_dir="$(mktemp -d "${TMPDIR:-/tmp}/vela-material-symbols.XXXXXX")"
source_font="${work_dir}/MaterialSymbolsRounded.woff2"
source_license="${work_dir}/LICENSE"
source_codepoints="${work_dir}/MaterialSymbolsRounded.codepoints"

cleanup() { find "${work_dir}" -type f -delete; rmdir "${work_dir}"; }
trap cleanup EXIT

curl --fail --silent --show-error --location \
  "https://raw.githubusercontent.com/google/material-design-icons/${revision}/variablefont/MaterialSymbolsRounded%5BFILL%2CGRAD%2Copsz%2Cwght%5D.woff2" \
  --output "${source_font}"
curl --fail --silent --show-error --location \
  "https://raw.githubusercontent.com/google/material-design-icons/${revision}/LICENSE" \
  --output "${source_license}"
curl --fail --silent --show-error --location \
  "https://raw.githubusercontent.com/google/material-design-icons/${revision}/variablefont/MaterialSymbolsRounded%5BFILL%2CGRAD%2Copsz%2Cwght%5D.codepoints" \
  --output "${source_codepoints}"

printf '%s  %s\n' "${font_sha256}" "${source_font}" | shasum --algorithm 256 --check --status
printf '%s  %s\n' "${license_sha256}" "${source_license}" | shasum --algorithm 256 --check --status
printf '%s  %s\n' "${codepoints_sha256}" "${source_codepoints}" | shasum --algorithm 256 --check --status

while read -r symbol codepoint; do
  grep --fixed-strings --line-regexp --quiet "${symbol} ${codepoint}" "${source_codepoints}"
done < "${script_dir}/symbols.txt"

unicodes="$(awk '{ printf "%sU+%s", separator, toupper($2); separator="," }' "${script_dir}/symbols.txt")"

mkdir -p "${project_root}/app/assets/fonts" "${project_root}/vendor/licenses"
python3 -m fontTools.subset "${source_font}" \
  --unicodes="${unicodes}" \
  --layout-features='' \
  --flavor=woff2 \
  --output-file="${project_root}/app/assets/fonts/material-symbols-rounded-subset.woff2"
cp "${source_license}" "${project_root}/vendor/licenses/google-material-design-icons-APACHE-2.0.txt"

shasum --algorithm 256 "${project_root}/app/assets/fonts/material-symbols-rounded-subset.woff2"
