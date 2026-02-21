# ---- Configuration ----
SOX=/opt/homebrew/bin/sox
SOXI=/opt/homebrew/bin/soxi
VERBOSE=0

# Supported input formats
SUPPORTED_EXTS=(wav flac aiff aif mp3 ogg m4a aac opus)

log() {
  [[ $VERBOSE -eq 1 ]] && echo "$@"
}

process_file() {
  local in="$1"
  local out="$2"
  mkdir -p "$(dirname "$out")"

  log "Normalizing: $in -> $out"

  local rate bits channels
  rate=$($SOXI -r "$in" 2>/dev/null) || rate=44100
  bits=$($SOXI -b "$in" 2>/dev/null) || bits=16
  channels=$($SOXI -c "$in" 2>/dev/null) || channels=2

  # Lossy formats (mp3, ogg, m4a, aac, opus) report compressed bit depth,
  # which is meaningless for PCM. Normalise to 16-bit minimum, 24-bit cap.
  local ext="${in##*.}"
  ext="${ext:l}"
  if [[ "$ext" == "mp3" || "$ext" == "ogg" || "$ext" == "m4a" \
     || "$ext" == "aac" || "$ext" == "opus" ]]; then
    # soxi may return 0 or a nonsense value for lossy; default to 16-bit
    if (( bits < 16 )); then
      bits=16
    elif (( bits > 24 )); then
      bits=24
    fi
  fi

  # Always write a WAV
  $SOX "$in" -t wav -r "$rate" -b "$bits" -c "$channels" "$out" gain -n -6
}

normalize_file() {
  local in="$1"
  local base="${in%.*}"
  local out="${base}_normalized.wav"   # always WAV
  process_file "$in" "$out"
}

normalize_folder() {
  local src="${1%/}"
  local dst="${src}_normalized"
  log "Processing folder: $src -> $dst"
  mkdir -p "$dst"

  # Build the find expression dynamically from SUPPORTED_EXTS
  local find_args=()
  local first=1
  for ext in "${SUPPORTED_EXTS[@]}"; do
    if (( first )); then
      find_args+=( -iname "*.${ext}" )
      first=0
    else
      find_args+=( -o -iname "*.${ext}" )
    fi
  done

  while IFS= read -r -d '' f; do
    local rel="${f#$src/}"
    local rel_noext="${rel%.*}"
    local out="$dst/${rel_noext}.wav"   # always WAV, preserving subdir structure
    process_file "$f" "$out"
  done < <(find "$src" -type f \( "${find_args[@]}" \) -print0)
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
        ext="${ext:l}"
        local supported=0
        for e in "${SUPPORTED_EXTS[@]}"; do
          [[ "$ext" == "$e" ]] && supported=1 && break
        done
        if (( supported )); then
          normalize_file "$arg"
        else
          log "Skipping: $arg (unsupported format)"
        fi
      else
        log "Skipping: $arg (not found)"
      fi
      ;;
  esac
done