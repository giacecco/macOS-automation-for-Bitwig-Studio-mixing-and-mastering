# prepare-filenames-for-UF8.sh

## Overview
A zsh script for macOS, suitable to be run as a "quick action" in Finder, that intelligently shortens filenames while preserving the original name in parentheses. Designed for audio producers and anyone working with long, descriptive filenames that need to be condensed for better visualizing on the display of Mackie-like devices like the SSL UF8, that offers only 6 characters per track.

## What It Does
The script recursively processes all files in a folder and renames them using a smart abbreviation algorithm, creating short 6-character names while keeping the full original name for reference.

### Example Transformations
- `60 Bridge Fred Durst.wav` → `BrFrDu (Bridge Fred Durst).wav`
- `32 Verse2 Salesman.wav` → `Ve2Sal (Verse2 Salesman).wav`
- `17 Bass.wav` → `Bass__ (Bass).wav`
- `71 BD Can't Stop Ctr.wav` → `BCTSCt (BD Can't Stop Ctr).wav`

## How It Works

### 1. Leading Numbers Removal
Leading numbers (often added by some DAW when exporting but not necessarily useful) are stripped from the filename:
- `60 Bridge Fred Durst` → `Bridge Fred Durst`

### 2. Trailing Numbers Preservation
Numbers at the end of the filename are kept as part of the abbreviation, as they could be particularly useful in representing the intention of the source:
- `Guitar2` → `Guita2` (keeps the 2)
- `Explosion1` → `Explo1` (keeps the 1)

### 3. Internal Number Handling
Numbers within words are treated as separate "words":
- `Verse2 Salesman` → words: `Verse`, `2`, `Salesman`
- `PC3 YEAH2` → words: `Pc`, `3`, `Ye`, `2`

### 4. Word Abbreviation Algorithm
The script creates a 6-character abbreviation by:
1. Taking the first letter of each word (capitalized)
2. Distributing remaining characters to words, prioritizing the **last words**
3. Adding lowercase letters from the end of words when space permits

**Examples:**
- `Bridge Fred Durst` (3 words, 6 chars available):
  - First letters: `B`, `F`, `D` = 3 chars
  - 3 chars remaining → distribute to last words
  - Result: `Br` + `Fr` + `Du` = `BrFrDu`

- `Impact` (1 word, 6 chars available):
  - Takes first 6 letters: `Impact`

- `Chorus Hi` (2 words, 6 chars available):
  - First letters: `C`, `H` = 2 chars
  - 4 chars remaining → add to both words
  - Result: `Chor` + `Hi` = `ChorHi`

### 5. Padding
If the generated name is shorter than 6 characters, it's padded with underscores:
- `Bass` → `Bass__`
- `Ding` → `Ding__`

### 6. Original Name Preservation
The full original name (without leading numbers) is added in parentheses:
- Final format: `SHORT_ (Original Name).ext`

### 7. Collision Handling
If two files would create the same shortened name, a counter is added:
- `ChGtrL (Chorus Gtr L).wav`
- `ChGtrL_2 (Chunky Gtr L).wav`

## Usage

### Command Line
```bash
# Basic usage
./rename.sh /path/to/folder

# Debug mode (shows what's happening)
VERBOSE=1 ./rename.sh /path/to/folder
```

### macOS Automator
1. Open Automator
2. Create a new "Quick Action"
3. Set "Workflow receives current" to **folders** in **Finder**
4. Add "Run Shell Script" action
5. Set Shell to `/bin/zsh`
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
- ✅ Special handling for numbers in filenames

## Requirements
- macOS (uses zsh)
- `awk` (pre-installed on macOS)
- `find` (pre-installed on macOS)

## Notes
- The script renames files in place
- Original filenames are preserved in parentheses for reference
- Files are only renamed if the new name differs from the current name
- The 6-character limit ensures compatibility with systems that have filename length restrictions
- Padding with underscores ensures consistent filename lengths for better sorting