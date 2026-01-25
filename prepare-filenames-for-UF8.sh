#!/usr/bin/env bash

# Silent file renamer for macOS/Automator
# Usage: ./rename.sh /path/to/folder
# Debug mode: VERBOSE=1 ./rename.sh /path/to/folder
# Version: ./rename.sh --version
VERSION="2025-01-25-v9-both-files-get-counters"

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
        
        # If word is all uppercase (already an abbreviation), preserve it in uppercase
        if (word ~ /^[A-Z]+$/) {
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
        
        # If target length >= word length, just return the whole word
        if (target_len >= len) {
            result = toupper(substr(word, 1, 1)) tolower(substr(word, 2))
            return result
        }
        
        # We need to drop (len - target_len) characters
        to_drop = len - target_len
        
        # Strategy: Drop vowels first from left to right (except first char)
        # This keeps consonants at the beginning
        
        # Mark all for inclusion initially
        for (i = 1; i <= len; i++) {
            include[i] = 1
        }
        
        dropped = 0
        
        # Pass 1: Drop vowels from left to right (except position 1)
        for (i = 2; i <= len && dropped < to_drop; i++) {
            if (is_v[i] && include[i]) {
                include[i] = 0
                dropped++
            }
        }
        
        # Pass 2: Drop consonants from end if needed (except position 1)
        for (i = len; i >= 2 && dropped < to_drop; i--) {
            if (!is_v[i] && include[i]) {
                include[i] = 0
                dropped++
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
        
        # Remove apostrophes before processing
        gsub(/'\''/, "", name)
        
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
        
        # Identify which words are all-caps (already abbreviations)
        for (i = 1; i <= num_words; i++) {
            word = words[i]
            # Check if word is all uppercase letters (and not a number)
            if (word ~ /^[A-Z]+$/ && word !~ /^[0-9]+$/) {
                is_abbrev[i] = 1
            } else {
                is_abbrev[i] = 0
            }
        }
        
        # Calculate available chars
        avail = max_chars
        if (length(trailing) > 0) {
            avail = max_chars - length(trailing)
            if (avail < 1) avail = 1
        }
        
        result = ""
        
        # Strategy: Preserve all-caps abbreviations, distribute rest to other words
        
        # First, allocate full length to all-caps words
        for (i = 1; i <= num_words; i++) {
            if (is_abbrev[i]) {
                word_lens[i] = length(words[i])
                avail = avail - word_lens[i]
            } else {
                word_lens[i] = 0
            }
        }
        
        # Count non-abbreviated words
        non_abbrev_count = 0
        for (i = 1; i <= num_words; i++) {
            if (!is_abbrev[i]) non_abbrev_count++
        }
        
        # If we have space left and non-abbreviated words, distribute to them
        if (avail > 0 && non_abbrev_count > 0) {
            # Give each non-abbrev word at least 1 character
            for (i = 1; i <= num_words; i++) {
                if (!is_abbrev[i]) {
                    word_lens[i] = 1
                    avail--
                }
            }
            
            # Distribute remaining chars round-robin to non-abbrev words
            while (avail > 0) {
                distributed = 0
                for (i = 1; i <= num_words && avail > 0; i++) {
                    if (!is_abbrev[i] && word_lens[i] < length(words[i])) {
                        word_lens[i]++
                        avail--
                        distributed = 1
                    }
                }
                # If we could not distribute any more, break
                if (!distributed) break
            }
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
        if [[ -e "$new_path" && "$new_path" != "$filepath" ]]; then
            # Collision detected! Rename the existing file to add counter "1"
            original_collision_path="$new_path"
            
            # Calculate collision name with "1"
            found_lower=""
            for ((i=${#new_name}-1; i>=0; i--)); do
                char="${new_name:$i:1}"
                if [[ "$char" =~ [a-z] ]]; then
                    first_collision_name="${new_name:0:$i}${new_name:$((i+1))}1"
                    found_lower=1
                    break
                fi
            done
            if [[ -z "$found_lower" ]]; then
                first_collision_name="${new_name:0:5}1"
            fi
            
            # Get the original filename of the existing file
            existing_base=$(basename "$original_collision_path")
            if [[ "$existing_base" == *.* ]]; then
                existing_ext="${existing_base##*.}"
                existing_nameonly="${existing_base%.*}"
                # Extract original name from parentheses using parameter expansion
                # Format is: "ShortN (Original Name)"
                if [[ "$existing_nameonly" == *"("*")"* ]]; then
                    # Extract everything between ( and )
                    temp="${existing_nameonly#*(}"
                    existing_original="${temp%)*}"
                    first_new_filename="${first_collision_name} (${existing_original}).${existing_ext}"
                else
                    first_new_filename="${first_collision_name}.${existing_ext}"
                fi
            else
                first_new_filename="${first_collision_name}"
            fi
            
            # Rename the existing file to add "1"
            first_new_path="${dir}/${first_new_filename}"
            mv "$original_collision_path" "$first_new_path" 2>/dev/null
            [[ -n "$VERBOSE" ]] && printf "  Renamed existing file to: %s\n" "$first_new_filename" >&2
            
            # Start counter at 2 for current file
            counter=2
        else
            counter=2
        fi
        
        # Check for additional collisions (counter 2, 3, 4, etc.)
        while [[ -e "$new_path" && "$new_path" != "$filepath" ]]; do
            # Keep exactly 6 chars with counter at the END
            # Remove lowercase letter(s) to make room, preserving capitals (word boundaries)
            
            if [[ $counter -lt 10 ]]; then
                # Single digit: remove 1 char (prefer lowercase) then append counter
                # Find last lowercase letter to remove
                found_lower=""
                for ((i=${#new_name}-1; i>=0; i--)); do
                    char="${new_name:$i:1}"
                    if [[ "$char" =~ [a-z] ]]; then
                        # Remove this lowercase and append counter at end
                        collision_name="${new_name:0:$i}${new_name:$((i+1))}${counter}"
                        found_lower=1
                        break
                    fi
                done
                # If no lowercase found, just replace last char
                if [[ -z "$found_lower" ]]; then
                    collision_name="${new_name:0:5}${counter}"
                fi
            else
                # Double digit: remove 2 chars (prefer lowercase) then append counter
                # Find last 2 lowercase letters to remove
                removed=0
                temp_name="$new_name"
                
                # Remove last lowercase
                for ((i=${#temp_name}-1; i>=0 && removed<2; i--)); do
                    char="${temp_name:$i:1}"
                    if [[ "$char" =~ [a-z] ]]; then
                        temp_name="${temp_name:0:$i}${temp_name:$((i+1))}"
                        removed=$((removed+1))
                        break
                    fi
                done
                
                # Remove second-to-last lowercase
                if [[ $removed -lt 2 ]]; then
                    for ((i=${#temp_name}-1; i>=0 && removed<2; i--)); do
                        char="${temp_name:$i:1}"
                        if [[ "$char" =~ [a-z] ]]; then
                            temp_name="${temp_name:0:$i}${temp_name:$((i+1))}"
                            removed=$((removed+1))
                            break
                        fi
                    done
                fi
                
                # If we removed enough lowercase, append counter
                if [[ $removed -eq 2 ]]; then
                    collision_name="${temp_name}${counter}"
                else
                    # Not enough lowercase, just truncate and append
                    collision_name="${new_name:0:4}${counter}"
                fi
            fi
            
            if [[ -n "$ext" ]]; then
                new_filename="${collision_name} (${nameonly}).${ext}"
            else
                new_filename="${collision_name} (${nameonly})"
            fi
            new_path="${dir}/${new_filename}"
            [[ -n "$VERBOSE" ]] && printf "  Collision, trying: %s\n" "$new_filename" >&2
            counter=$((counter + 1))
            
            # Safety: stop at 99 to avoid infinite loop
            if [[ $counter -gt 99 ]]; then
                [[ -n "$VERBOSE" ]] && printf "  ERROR: Too many collisions (>99)\n" >&2
                break
            fi
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