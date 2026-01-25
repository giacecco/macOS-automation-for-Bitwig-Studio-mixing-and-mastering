#!/usr/bin/env bash

# Silent file renamer for macOS/Automator
# Usage: ./rename.sh /path/to/folder
# Debug mode: VERBOSE=1 ./rename.sh /path/to/folder
# Version: ./rename.sh --version
VERSION="2025-01-25-v4-word-balanced"

# Show version if requested
if [[ "$1" == "--version" || "$1" == "-v" ]]; then
    echo "rename.sh version $VERSION"
    echo "Features: 6-char abbreviation, consonant priority, original name in parentheses"
    exit 0
fi

# Validate input
[[ $# -ne 1 ]] && { echo "Error: Exactly one folder argument required" >&2; exit 1; }
[[ ! -d "$1" ]] && { echo "Error: Argument must be a directory" >&2; exit 1; }

# Function to generate shortened name using awk
generate_short_name() {
    local input="$1"
    
    # Use awk to do all the processing
    echo "$input" | awk '
    BEGIN { max_chars = 6 }
    
    function is_vowel(char) {
        return (char ~ /[aeiouAEIOU]/)
    }
    
    function abbreviate_word(word, target_len) {
        if (word == "") return ""
        
        # If word is purely numeric, just truncate it
        if (word ~ /^[0-9]+$/) {
            return substr(word, 1, target_len)
        }
        
        # Clear arrays from previous calls
        delete chars
        delete is_v
        delete include
        
        # Build character array with vowel flags
        len = length(word)
        for (i = 1; i <= len; i++) {
            chars[i] = substr(word, i, 1)
            is_v[i] = is_vowel(chars[i])
        }
        
        # Mark which positions to include
        # Always include first character
        include[1] = 1
        included_count = 1
        
        if (included_count >= target_len) {
            return toupper(chars[1])
        }
        
        # First pass: mark consonants for inclusion
        for (i = 2; i <= len && included_count < target_len; i++) {
            if (!is_v[i]) {
                include[i] = 1
                included_count++
            }
        }
        
        # Second pass: mark vowels for inclusion if we still have room
        for (i = 2; i <= len && included_count < target_len; i++) {
            if (is_v[i]) {
                include[i] = 1
                included_count++
            }
        }
        
        # Build result string in original order
        result = ""
        for (i = 1; i <= len; i++) {
            if (include[i]) {
                if (i == 1) {
                    result = result toupper(chars[i])
                } else {
                    result = result tolower(chars[i])
                }
            }
        }
        
        return result
    }
    
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
        gsub(/[^a-zA-Z0-9]+/, " ", name)
        gsub(/  +/, " ", name)
        gsub(/^ | $/, "", name)
        
        # Split into words
        n = split(name, temp_words, " ")
        
        # Further split words that end with numbers
        num_words = 0
        for (i = 1; i <= n; i++) {
            if (temp_words[i] == "") continue
            
            word = temp_words[i]
            if (match(word, /[a-zA-Z]+[0-9]+$/)) {
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
        
        # Strategy: Distribute chars to maximize average word completion
        # Within each word, prioritize consonants then vowels
        
        # Calculate how many chars each word gets
        for (i = 1; i <= num_words; i++) {
            word_lens[i] = 1  # Start with first letter of each word
        }
        
        remaining = avail - num_words
        
        # Distribute remaining chars round-robin
        while (remaining > 0) {
            distributed = 0
            for (i = 1; i <= num_words && remaining > 0; i++) {
                if (word_lens[i] < length(words[i])) {
                    word_lens[i]++
                    remaining--
                    distributed = 1
                }
            }
            # If we could not distribute any more, break
            if (!distributed) break
        }
        
        # Now build each word using consonant-first within that word
        for (w = 1; w <= num_words; w++) {
            result = result abbreviate_word(words[w], word_lens[w])
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
    dir=$(dirname "$filepath")
    base=$(basename "$filepath")
    
    [[ -n "$VERBOSE" ]] && printf "Checking: %s\n" "$base" >&2
    
    # Skip hidden files
    if [[ "$base" == .* ]]; then
        [[ -n "$VERBOSE" ]] && printf "  Skipping hidden file\n" >&2
        continue
    fi
    
    # Extract extension and name
    ext=""
    nameonly=""
    if [[ "$base" == *.* ]]; then
        ext="${base##*.}"
        nameonly="${base%.*}"
    else
        nameonly="$base"
    fi
    
    # Generate new name
    new_name=$(generate_short_name "$nameonly")
    
    # Pad short names with underscores to reach 6 characters
    while [[ ${#new_name} -lt 6 ]]; do
        new_name="${new_name}_"
    done
    
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