#!/usr/bin/env bash
# Converts HEIC/HEIF media attachments from Pixelfed posts to JPEG at build time,
# since Chrome/Firefox do not natively render HEIC images and Pixelfed returns
# "no-preview.png" when it cannot generate a thumbnail for HEIC uploads.
set -euo pipefail

if ! command -v heif-convert >/dev/null 2>&1; then
  echo "[convert-pixelfed-heic] warning: heif-convert not found, skipping HEIC conversion" >&2
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "[convert-pixelfed-heic] warning: jq not found, skipping HEIC conversion" >&2
  exit 0
fi

PARAMS_FILE="config/_default/params.toml"
OUT_DIR="assets/media/pixelfed"
mkdir -p "$OUT_DIR"

# Parse [pixelfed] instance and accountId from params.toml (fallback to defaults)
PF_INSTANCE="https://gram.social"
PF_ACCOUNT_ID="1028069983218190198"

if [ -f "$PARAMS_FILE" ]; then
  parsed_instance=$(awk '
    /^\[pixelfed\]/ { in_sec=1; next }
    /^\[/ { in_sec=0 }
    in_sec && /^[[:space:]]*instance[[:space:]]*=/ {
      gsub(/.*=[[:space:]]*"|".*/, "")
      print; exit
    }
  ' "$PARAMS_FILE")
  parsed_account=$(awk '
    /^\[pixelfed\]/ { in_sec=1; next }
    /^\[/ { in_sec=0 }
    in_sec && /^[[:space:]]*accountId[[:space:]]*=/ {
      gsub(/.*=[[:space:]]*"|".*/, "")
      print; exit
    }
  ' "$PARAMS_FILE")
  [ -n "${parsed_instance:-}" ] && PF_INSTANCE="${parsed_instance%/}"
  [ -n "${parsed_account:-}" ] && PF_ACCOUNT_ID="$parsed_account"
fi

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

process_json_stream() {
  jq -r '
    .[]? |
    .media_attachments[]? |
    select(
      ((.mime // "") | ascii_downcase | test("^image/hei[cf]$")) or
      ((.url // "") | ascii_downcase | test("\\.hei[cf](\\?|$)"))
    ) |
    "\(.id)\t\(.url)"
  ' | while IFS=$'\t' read -r att_id att_url; do
    [ -z "$att_id" ] || [ -z "$att_url" ] && continue
    # Sanitize attachment ID for filename safety
    safe_id=$(printf '%s' "$att_id" | tr -cd 'A-Za-z0-9_-')
    [ -z "$safe_id" ] && continue

    out_file="${OUT_DIR}/${safe_id}.jpg"
    if [ -s "$out_file" ]; then
      continue
    fi

    echo "[convert-pixelfed-heic] Converting attachment ${safe_id} from ${att_url}"
    tmp_in="${TMP_DIR}/${safe_id}.heic"
    tmp_out="${TMP_DIR}/${safe_id}.jpg"
    if curl -fsSL --max-time 30 "$att_url" -o "$tmp_in"; then
      if heif-convert -q 85 "$tmp_in" "$tmp_out" >/dev/null 2>&1; then
        if [ -s "$tmp_out" ]; then
          mv "$tmp_out" "$out_file"
        elif [ -s "${TMP_DIR}/${safe_id}-1.jpg" ]; then
          mv "${TMP_DIR}/${safe_id}-1.jpg" "$out_file"
        else
          echo "[convert-pixelfed-heic] warning: heif-convert produced no output for ${safe_id}" >&2
        fi
      else
        echo "[convert-pixelfed-heic] warning: heif-convert failed for ${safe_id}" >&2
      fi
    else
      echo "[convert-pixelfed-heic] warning: failed to download ${att_url}" >&2
    fi
  done
}

# 1. Check optional local Pixelfed archive
if [ -f "data/pixelfed/archive.json" ]; then
  process_json_stream < "data/pixelfed/archive.json"
fi

# 2. Fetch live Pixelfed statuses (up to 5 pages, matching _content.gotmpl)
max_id=""
for _ in 1 2 3 4 5; do
  url="${PF_INSTANCE}/api/pixelfed/v1/accounts/${PF_ACCOUNT_ID}/statuses?only_media=true"
  [ -n "$max_id" ] && url="${url}&max_id=${max_id}"

  resp_file="${TMP_DIR}/page.json"
  if ! curl -fsSL --max-time 30 "$url" -o "$resp_file"; then
    echo "[convert-pixelfed-heic] warning: failed to fetch ${url}" >&2
    break
  fi

  count=$(jq 'if type == "array" then length else 0 end' "$resp_file" 2>/dev/null || echo 0)
  if [ "$count" -eq 0 ]; then
    break
  fi

  process_json_stream < "$resp_file"

  max_id=$(jq -r '.[-1].id // ""' "$resp_file" 2>/dev/null || echo "")
  if [ "$count" -lt 9 ] || [ -z "$max_id" ]; then
    break
  fi
done
