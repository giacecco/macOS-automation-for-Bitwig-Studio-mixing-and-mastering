#!/bin/zsh

# Silent file renamer for macOS/Automator
# Usage: ./rename.sh /path/to/folder
# Debug mode: VERBOSE=1 ./rename.sh /path/to/folder
# VERSION: 2025-01-25 with parentheses support

# Disable all tracing and warnings
setopt no_xtrace 2>/dev/null
setopt no_warn_create_global 2>/dev/null

# Validate input
[[ $# -ne 1 ]] && { echo "Error: Exactly one folder argument required" >&2; exit 1; }
[[ ! -d "$1" ]] && { echo "Error: Argument must be a directory" >&2; exit 1; }

# Function to generate shortened name using awk
generate_short_name() {
    local input="$1"
    
    # Use awk to do all the processing
    echo "$input" | awk '
    BEGIN { max_chars = 6 }
    {
        name = $0
        
        # Remove leading numbers/spaces/dashes/underscores
        gsub(/^[0-9_ -]+/, "", name)
        
        # Extract trailing number
        trailing = ""
        if (match(name, /[0-9]+$/)) {
            trailing = substr(name, RSTART, RLENGTH)
            name = substr(name, 1, RSTART-1)
        }
        
        # Remove non-alphanumeric but keep internal numbers as separate words
        # First replace non-alphanumeric with spaces
        gsub(/[^a-zA-Z0-9]+/, " ", name)
        gsub(/  +/, " ", name)
        gsub(/^ | $/, "", name)
        
        # Split into words (now includes number words)
        n = split(name, temp_words, " ")
        
        # Further split words that end with numbers (e.g., "Verse2" -> "Verse" "2")
        num_words = 0
        for (i = 1; i <= n; i++) {
            if (temp_words[i] == "") continue
            
            word = temp_words[i]
            # Check if word ends with number
            if (match(word, /[a-zA-Z]+[0-9]+$/)) {
                # Split into letter part and number part
                letter_part = word
                gsub(/[0-9]+$/, "", letter_part)
                number_part = word
                gsub(/^[a-zA-Z]+/, "", number_part)
                
                num_words++
                words[num_words] = letter_part
                num_words++
                words[num_words] = number_part
            } else {
                num_words++
                words[num_words] = word
            }
        }
        
        if (num_words == 0) {
            print "File"
            exit
        }
        
        # Calculate available chars
        avail = max_chars
        if (length(trailing) > 0) {
            avail = max_chars - length(trailing)
            if (avail < 1) avail = 1
        }
        
        result = ""
        
        if (num_words <= avail) {
            # Calculate how many letters each word should get
            for (i = 1; i <= num_words; i++) {
                word_lens[i] = 1  # Start with 1 letter per word
            }
            
            # Distribute remaining characters, starting from last word
            remaining = avail - num_words
            idx = num_words
            
            while (remaining > 0) {
                # Can we add another letter to this word?
                if (word_lens[idx] < length(words[idx])) {
                    word_lens[idx]++
                    remaining--
                }
                
                # Move to previous word
                idx--
                if (idx < 1) idx = num_words
                
                # Safety: check if all words are exhausted
                can_add = 0
                for (i = 1; i <= num_words; i++) {
                    if (word_lens[i] < length(words[i])) can_add = 1
                }
                if (!can_add) break
            }
            
            # Build result with calculated lengths
            for (i = 1; i <= num_words; i++) {
                word = words[i]
                # Check if word is purely numeric
                if (word ~ /^[0-9]+$/) {
                    # Number word - just use it as-is (uppercase not needed)
                    result = result substr(word, 1, word_lens[i])
                } else {
                    # Letter word - capitalize first, lowercase rest
                    first_char = toupper(substr(word, 1, 1))
                    rest = ""
                    if (word_lens[i] > 1) {
                        rest = tolower(substr(word, 2, word_lens[i] - 1))
                    }
                    result = result first_char rest
                }
            }
        } else {
            # Take first letters only
            for (i = 1; i <= avail; i++) {
                word = words[i]
                if (word ~ /^[0-9]+$/) {
                    # Number word - use first digit
                    result = result substr(word, 1, 1)
                } else {
                    # Letter word - capitalize first letter
                    result = result toupper(substr(word, 1, 1))
                }
            }
        }
        
        # Add trailing number
        result = result trailing
        
        # Ensure max length
        print substr(result, 1, max_chars)
    }'
}

# Collect all files
files=()
while IFS= read -r -d '' filepath; do
    files+=("$filepath")
done < <(find "$1" -type f -print0)

[[ -n "$VERBOSE" ]] && printf "Found %d files to process\n" "${#files[@]}" >&2

# Process each file
for filepath in "${files[@]}"; do
    dir="${filepath:h}"
    base="${filepath:t}"
    
    [[ -n "$VERBOSE" ]] && printf "Checking: %s\n" "$base" >&2
    
    # Skip hidden files
    if [[ "$base" == .* ]]; then
        [[ -n "$VERBOSE" ]] && printf "  Skipping hidden file\n" >&2
        continue
    fi
    
    # Extract extension and name
    local ext=""
    local nameonly=""
    if [[ "$base" == *.* ]]; then
        ext="${base:e}"
        nameonly="${base:r}"
    else
        nameonly="$base"
    fi
    
    # Generate new name
    new_name=$(generate_short_name "$nameonly")
    
    # Pad short names with underscores to reach 6 characters
    while [[ ${#new_name} -lt 6 ]]; do
        new_name="${new_name}_"
    done
    
    # VERSION CHECK: This should add parentheses with original name
    # Build new filename with original name in parentheses
    if [[ -n "$ext" ]]; then
        new_filename="${new_name} (${nameonly}).${ext}"
    else
        new_filename="${new_name} (${nameonly})"
    fi
    
    [[ -n "$VERBOSE" ]] && printf "  Generated: %s (from: %s)\n" "$new_name" "$nameonly" >&2
    [[ -n "$VERBOSE" ]] && printf "  New filename will be: %s\n" "$new_filename" >&2
    
    # Rename if different
    if [[ "$base" != "$new_filename" ]]; then
        new_path="${dir}/${new_filename}"
        
        [[ -n "$VERBOSE" ]] && printf "  Will rename: %s -> %s\n" "$base" "$new_filename" >&2
        
        # Handle collisions
        counter=2
        while [[ -e "$new_path" && "$new_path" != "$filepath" ]]; do
            if [[ -n "$ext" ]]; then
                new_filename="${new_name}_${counter} (${nameonly}).${ext}"
            else
                new_filename="${new_name}_${counter} (${nameonly})"
            fi
            new_path="${dir}/${new_filename}"
            [[ -n "$VERBOSE" ]] && printf "  Collision, trying: %s\n" "$new_filename" >&2
            counter=$((counter + 1))
        done
        
        mv "$filepath" "$new_path" 2>/dev/null
        if [[ $? -eq 0 ]]; then
            [[ -n "$VERBOSE" ]] && printf "  ✓ Renamed\n" >&2
        else
            [[ -n "$VERBOSE" ]] && printf "  ✗ Failed to rename\n" >&2
        fi
    else
        [[ -n "$VERBOSE" ]] && printf "  Already correct\n" >&2
    fi
done

[[ -n "$VERBOSE" ]] && printf "Complete!\n" >&2
exit 0