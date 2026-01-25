#!/bin/zsh

# Silent file renamer for macOS/Automator
# Usage: ./rename.sh /path/to/folder
# Debug mode: VERBOSE=1 ./rename.sh /path/to/folder
# Version: ./rename.sh --version
VERSION="2025-01-25-v3-consonant-priority"

# Show version if requested
if [[ "$1" == "--version" || "$1" == "-v" ]]; then
    echo "rename.sh version $VERSION"
    echo "Features: 6-char abbreviation, consonant priority, original name in parentheses"
    exit 0
fi

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
    
    function is_vowel(char) {
        return (char ~ /[aeiouAEIOU]/)
    }
    
    function abbreviate_word(word, target_len) {
        if (word == "") return ""
        
        # If word is purely numeric, just truncate it
        if (word ~ /^[0-9]+$/) {
            return substr(word, 1, target_len)
        }
        
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
        
        # Build character pool from all words
        # Format: char_pool[index] = {char, word_idx, char_idx, is_first, is_vowel}
        pool_size = 0
        
        for (w = 1; w <= num_words; w++) {
            word = words[w]
            word_len = length(word)
            
            for (c = 1; c <= word_len; c++) {
                pool_size++
                char = substr(word, c, 1)
                pool_char[pool_size] = char
                pool_word_idx[pool_size] = w
                pool_char_idx[pool_size] = c
                pool_is_first[pool_size] = (c == 1)
                pool_is_vowel[pool_size] = is_vowel(char)
                pool_is_digit[pool_size] = (char ~ /[0-9]/)
            }
        }
        
        # Mark characters for inclusion
        included = 0
        
        # Pass 1: Include first char of each word
        for (i = 1; i <= pool_size && included < avail; i++) {
            if (pool_is_first[i]) {
                pool_include[i] = 1
                included++
            }
        }
        
        # Pass 2: Include remaining consonants (not first chars)
        for (i = 1; i <= pool_size && included < avail; i++) {
            if (!pool_include[i] && !pool_is_vowel[i] && !pool_is_first[i]) {
                pool_include[i] = 1
                included++
            }
        }
        
        # Pass 3: Include vowels (not first chars)
        for (i = 1; i <= pool_size && included < avail; i++) {
            if (!pool_include[i] && pool_is_vowel[i] && !pool_is_first[i]) {
                pool_include[i] = 1
                included++
            }
        }
        
        # Build result from included characters
        for (i = 1; i <= pool_size; i++) {
            if (pool_include[i]) {
                char = pool_char[i]
                if (pool_is_first[i]) {
                    result = result toupper(char)
                } else {
                    result = result tolower(char)
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