# prepare-filenames-for-UF8.sh

## Overview
A bash script for macOS, suitable to be run as a "quick action" in Finder, that intelligently shortens filenames while preserving the original name in parentheses. Designed for audio producers and anyone working with long, descriptive filenames that need to be condensed for better visualizing on the display of Mackie-like devices like the SSL UF8, that offers only 6 characters per track.

## What It Does
The script recursively processes all files in a folder and renames them using a smart abbreviation algorithm, creating short 6-character names while keeping the full original name for reference.

### Example Transformations
- `60 Bridge Fred Durst.wav` → `BrFrDu (60 Bridge Fred Durst).wav`
- `32 Verse2 Salesman.wav` → `Ve2Sal (32 Verse2 Salesman).wav`
- `17 Bass.wav` → `Bass__ (17 Bass).wav`
- `71 BD Can't Stop Ctr.wav` → `BDCntS (71 BD Can't Stop Ctr).wav` *(apostrophe removed, BD preserved as all-caps)*
- `05 Shotgun.wav` → `Shtgun (05 Shotgun).wav`
- `34 Guitar Left 3.wav` → `GtrLf3 (34 Guitar Left 3).wav`
- `45 Chorus DT L.wav` → `ChrDTL (45 Chorus DT L).wav` *(DT and L preserved as abbreviations)*

## How It Works

### 1. Leading Numbers Removal
Leading numbers (often added by some DAW when exporting but not necessarily useful for display) are stripped from the filename during processing but preserved in the parenthetical original name:
- `60 Bridge Fred Durst` → processes as `Bridge Fred Durst`
- Final result: `BrFrDu (60 Bridge Fred Durst).wav`

### 2. Apostrophe Removal
Apostrophes are removed from filenames before processing to avoid fragmentation:
- `Can't` → `Cant`
- `I'm` → `Im`
- `Don't` → `Dont`

This prevents words like "Can't" from being split into "Can" and "t", ensuring all characters are used for meaningful words.

### 3. Trailing Numbers Preservation
Numbers at the end of the filename are kept as part of the abbreviation, as they are particularly useful in representing variants or takes:
- `Guitar2` → `Guitr2` (keeps the 2)
- `Explosion1` → `Expls1` (keeps the 1)
- Trailing numbers reduce available characters: with trailing "2", only 5 chars remain for the abbreviation

### 4. Internal Number Handling
Numbers within words are treated as separate "words":
- `Verse2 Salesman` → words: `Verse`, `2`, `Salesman`
- `PC3 YEAH2` → words: `Pc`, `3`, `YEAH`, `2`

### 5. All-Caps Abbreviation Preservation
Words that are entirely in uppercase are recognized as existing abbreviations and preserved with priority:
- `DT` (distortion), `L` (left), `R` (right), `FX` (effects), `BD` (bass drum) are kept in full
- These get their full character allocation before distributing to other words
- They remain in uppercase in the final abbreviation

**Examples:**
- `Chorus DT L` → `DT` and `L` are preserved → result: `ChrDTL`
- `BD Scream Monster` → `BD` gets 2 chars, others share remaining → `BDScrM`
- `Guitar FX Wet` → `FX` gets 2 chars → `GtrFXW`

This ensures that meaningful audio engineering abbreviations like L/R (stereo), FX (effects), BD (bass drum), etc. are always readable.

### 6. Word Abbreviation Algorithm
The script creates a 6-character abbreviation using a **round-robin character distribution** strategy:

**Step 1: Calculate Available Characters**
- Start with 6 characters total
- Subtract trailing number length (if any)
- Example: `Guitar2` has trailing "2", so 5 chars available for abbreviation

**Step 2: Distribute Characters with All-Caps Priority**
1. First, allocate full length to any all-caps words (existing abbreviations)
2. Calculate remaining available characters
3. Give each non-abbreviated word 1 character (its first letter, capitalized)
4. Distribute remaining characters evenly across non-abbreviated words, cycling through them
5. This maximizes the average number of letters preserved from each word while keeping important abbreviations intact

**Step 3: Abbreviate Each Word (Consonant-Priority)**
For each word, given its allocated character count:
1. Always include the first letter (capitalized)
2. Drop vowels first (left to right, starting from position 2) to preserve consonants
3. Only drop consonants if necessary (from the end)
4. Maintain original character order in the result

**Examples:**

*Example 1: Multiple Words with Even Distribution*
- `Bridge Fred Durst` (3 words, 6 chars available):
  - Each word starts with 1 char: `B`, `F`, `D` = 3 chars used
  - 3 chars remaining → distribute round-robin: 1 to each word
  - `Bridge` gets 2 chars → `Br`
  - `Fred` gets 2 chars → `Fr`
  - `Durst` gets 2 chars → `Du`
  - Result: `BrFrDu`

*Example 2: Single Word*
- `Shotgun` (1 word, 6 chars available):
  - `Shotgun` gets all 6 chars
  - Word is 7 chars, need to drop 1
  - Drop vowel 'o' (first vowel after 'S')
  - Result: `Shtgun`

*Example 3: Two Words*
- `Chorus Lo` (2 words, 6 chars available):
  - Each word starts with 1 char: `C`, `L` = 2 chars used
  - 4 chars remaining → distribute round-robin (2 to each)
  - `Chorus` gets 3 chars → `Chr` (drops vowels 'o', 'u')
  - `Lo` gets 3 chars → but `Lo` is only 2 chars, so `Lo`
  - Actually: distribute gives `Chorus` 4 chars, `Lo` 2 chars
  - `Chorus` with 4 chars → `Chrs` (C-h-r-s, drops vowels o,u)
  - `Lo` with 2 chars → `Lo` (complete word)
  - Result: `ChrsLo`

*Example 4: With Trailing Number*
- `Guitar Left 3` (2 words + trailing "3", 5 chars available):
  - Each word starts with 1 char: `G`, `L` = 2 chars used
  - 3 chars remaining → distribute round-robin
  - `Guitar` gets 3 chars → `Gtr` (G-t-r, drops vowels u,i,a)
  - `Left` gets 2 chars → `Lf` (L-f, drops vowels e)
  - Add trailing: `GtrLf3`

*Example 5: With All-Caps Abbreviations*
- `Chorus DT L` (3 words, 6 chars available):
  - Identify all-caps: `DT` (2 chars), `L` (1 char) = 3 chars reserved
  - 3 chars remaining for `Chorus`
  - `Chorus` gets 3 chars → `Chr` (C-h-r, drops vowels o,u,s)
  - `DT` preserved → `DT`
  - `L` preserved → `L`
  - Result: `ChrDTL`

*Example 6: Multiple All-Caps Words*
- `BD FX Wet` (3 words, 6 chars available):
  - Identify all-caps: `BD` (2 chars), `FX` (2 chars) = 4 chars reserved
  - 2 chars remaining for `Wet`
  - `Wet` gets 2 chars → `Wt` (W-t, drops vowel e)
  - `BD` preserved → `BD`
  - `FX` preserved → `FX`
  - Result: `BDFXWt` (or reordered based on original: `WtBDFX` if Wet came first)

### 7. Padding
If the generated name is shorter than 6 characters, it's padded with underscores:
- `Bass` → `Bass__`
- `Ding` → `Ding__`

### 8. Original Name Preservation
The full original name (including leading numbers) is added in parentheses:
- Final format: `SHORT_ (Original Name).ext`
- Example: `BrFrDu (60 Bridge Fred Durst).wav`

### 9. Collision Handling
If two files would create the same shortened name, a counter is added:
- `ChGtrL (21 Chorus Gtr L).wav`
- `ChGtrL_2 (23 Chunky Gtr L).wav`

## Usage

### Command Line
```bash
# Basic usage
./rename.sh /path/to/folder

# Debug mode (shows what's happening)
VERBOSE=1 ./rename.sh /path/to/folder

# Check version
./rename.sh --version
```

### macOS Automator
1. Open Automator
2. Create a new "Quick Action"
3. Set "Workflow receives current" to **folders** in **Finder**
4. Add "Run Shell Script" action
5. Set Shell to `/bin/bash`
6. Set "Pass input" to **as arguments**
7. Paste the entire script
8. Save with a name like "Rename Files Short"

Now you can right-click any folder in Finder → Quick Actions → "Rename Files Short"

## Features
- ✅ Silent operation (no output unless VERBOSE=1)
- ✅ Processes all files recursively in a folder
- ✅ Preserves file extensions
- ✅ Skips hidden files (those starting with `.`)
- ✅ Handles filename collisions automatically
- ✅ Maintains original name for reference
- ✅ Smart abbreviation that maximizes word representation
- ✅ Preserves all-caps words as existing abbreviations (e.g., L, R, FX, DT, BD)
- ✅ Consonant-priority within each word for better readability
- ✅ Special handling for numbers in filenames
- ✅ Round-robin character distribution across words
- ✅ Bash-compatible for macOS

## Requirements
- bash (pre-installed on macOS)
- `awk` (pre-installed on macOS)
- `find` (pre-installed on macOS)
- `dirname` and `basename` utilities (standard on macOS)

## Algorithm Details

### Why Preserve All-Caps Words?
In audio production, all-caps abbreviations like L/R (left/right channels), FX (effects), DT (distortion), BD (bass drum), etc. are industry-standard and already maximally compressed. The script recognizes words that are entirely uppercase (excluding numbers) as existing abbreviations and preserves them with priority. This ensures critical channel/track identifiers remain readable on limited displays.

### Why Round-Robin Distribution?
The round-robin approach ensures that when abbreviating multi-word filenames, characters are distributed evenly across all words rather than favoring earlier words. This maximizes the average number of letters preserved from each word, making abbreviations more recognizable.

### Why Consonant-Priority?
Within each word, consonants are preserved over vowels because:
- Consonants carry more identifying information
- Words remain more readable without vowels (e.g., "Gtr" vs "uia")
- This is similar to how text message abbreviations work naturally

### Character Dropping Strategy
When a word needs to be shortened:
1. First letter is always kept (capitalized for visibility)
2. Vowels are dropped from left to right (after the first letter)
3. Only if more characters must be dropped are consonants removed from the end

Example: `Shotgun` (7 chars) → 6 chars needed
- Keep: S (position 1, always kept)
- Drop: o (position 3, first vowel after S)
- Keep: h, t, g, u, n
- Result: `Shtgun`

## Notes
- The script renames files in place
- Original filenames are preserved in parentheses for reference
- Files are only renamed if the new name differs from the current name
- The 6-character limit ensures compatibility with systems like the SSL UF8 that have display limitations
- Padding with underscores ensures consistent filename lengths for better sorting and display alignment

## Version
Current version: `2025-01-25-v7-remove-apostrophes`

Features in this version:
- 6-character abbreviation
- Apostrophe removal to prevent word fragmentation
- All-caps word preservation (words like DT, L, R, FX, BD are kept intact)
- Consonant priority within words
- Round-robin character distribution across words
- Original name preservation in parentheses
- Bash compatibility for macOS