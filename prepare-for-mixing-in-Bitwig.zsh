#!/bin/zsh

# ---- Configuration ----
SOX=/opt/homebrew/bin/sox
SOXI=/opt/homebrew/bin/soxi
VERBOSE=0

log() {
  [[ $VERBOSE -eq 1 ]] && echo "$@"
}

process_file() {
  local in="$1"
  local out="$2"

  mkdir -p "$(dirname "$out")"

  # Overwrite existing files by default
  log "Normalizing: $in -> $out"
  local rate bits channels
  rate=$($SOXI -r "$in")
  bits=$($SOXI -b "$in")
  channels=$($SOXI -c "$in")

  $SOX "$in" -r "$rate" -b "$bits" -c "$channels" "$out" gain -n -6
}

normalize_file() {
  local in="$1"
  local ext="${in##*.}"
  local base="${in%.*}"
  local out="${base}_normalized.${ext}"
  process_file "$in" "$out"
}

normalize_folder() {
  local src="${1%/}"
  local dst="${src}_normalized"

  log "Processing folder: $src -> $dst"
  mkdir -p "$dst"

  # Loop through files safely
  while IFS= read -r -d '' f; do
    local rel="${f#$src/}"
    local out="$dst/$rel"
    process_file "$f" "$out"
  done < <(find "$src" -type f \( -iname "*.wav" -o -iname "*.flac" \) -print0)
}

# ---- Main ----
ARGS=("$@")
for arg in "${ARGS[@]}"; do
  case "$arg" in
    -v|--verbose)
      VERBOSE=1
      ;;
    *)
      if [[ -d "$arg" ]]; then
        normalize_folder "$arg"
      elif [[ -f "$arg" ]]; then
        local ext="${arg##*.}"
        ext="${ext:l}"   # zsh lowercase
        if [[ "$ext" == "wav" || "$ext" == "flac" ]]; then
          normalize_file "$arg"
        fi
      else
        log "Skipping: $arg (not found)"
      fi
      ;;
  esac
done
