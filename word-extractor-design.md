# Word Extractor — Design

## Overview

An interpretation layer on top of the transcript JSONL that detects words typed by the user, measuring speed and mistakes per word. The output is a JSON file suitable for import into a typing game to target specific words.

## Input: Transcript Events

Each line in `transcript.jsonl` is a JSON object:

```json
{
  "seq": 1,
  "ts": "2026-04-14T17:29:15.673Z",
  "type": "keyDown | keyUp",
  "keyCode": 17,
  "characters": "T",
  "charactersIgnoringModifiers": "T",
  "modifiers": ["shift"],
  "isRepeat": false,
  "keyboardLayout": null
}
```

## Word Detection Algorithm

Process events in `seq` order. Only `keyDown` events build/modify the word buffer; `keyUp` events are used solely for timing the end of a word.

### Character classification (by `characters` value, not keyCode)

| Character | Action |
|-----------|--------|
| `" "` (space) | Finalize current word |
| `"\r"` (return) | Finalize current word |
| `"\t"` (tab) | Finalize current word |
| `"\u{1B}"` (escape) | Finalize current word |
| `"\u{7F}"` (DEL / backspace) | Pop last char from buffer, increment mistake count |
| `>= \u{F700}` (arrow keys, function keys) | Finalize current word |
| `.` `,` `?` `!` `"` `;` `:` `(` `)` `[` `]` `{` `}` | Finalize current word (punctuation boundary) |
| `—` (em dash), `–` (en dash), `-` (hyphen) | Finalize current word |
| `"` `"` (smart double quotes) | Finalize current word |
| `0`–`9` (digits) | Finalize current word |
| `'` (apostrophe / smart apostrophe) | Append to word buffer (trimmed from edges on finalize) |
| Any other printable character | Append to word buffer |

### Additional word boundary rules

- **Time gap > 2 seconds** between consecutive `keyDown` events → implicit word boundary (catches app/context switches).
- **Modifier-delete** (`option+backspace` or `command+backspace`) → **drop the current word entirely**. We cannot know the scope of the deletion, so the word is discarded.
- **Command/control-modified keys** → skip entirely. These are shortcuts (Cmd+C, Cmd+V, Cmd+Z), not typing.
- **Shift-modified keys** are kept — they represent normal capitalized typing.

### Apostrophe handling

- Apostrophes (`'` and the smart apostrophe `'`) are allowed **inside** words to support contractions (e.g., `don't`, `it's`).
- Leading and trailing apostrophes are **trimmed** during finalization (e.g., `'hello'` → `hello`).

### Word filtering

After finalization, a word is **discarded** if:

- It is empty (fully backspaced, or only apostrophes that were trimmed).
- It is a single character (likely a stray keystroke).
- It consists only of punctuation (no letters).

### Mistake counting

- Each backspace (`\u{7F}`) without command/option modifier counts as **1 mistake**, including `isRepeat` events from holding backspace.
- Mistakes are scoped to the word they occur in.
- Example: `t-h-i-g-n-⌫-⌫-n-g-s` → word is `"things"`, `mistakeCount: 2`.

### Timing

- `durationMs` = timestamp of the **last `keyUp`** for the final character minus the timestamp of the **first `keyDown`** in the word.
- Millisecond precision derived from ISO 8601 timestamps.

## Output JSON

Written to `~/Library/Application Support/TypingLens/extracted-words.json`.

```json
{
  "extractedAt": "2026-04-14T19:00:00.000Z",
  "totalWords": 142,
  "words": [
    {
      "word": "testing",
      "characters": 7,
      "durationMs": 1076.0,
      "mistakeCount": 0
    },
    {
      "word": "proceed",
      "characters": 7,
      "durationMs": 932.0,
      "mistakeCount": 2
    }
  ]
}
```

### Field definitions

| Field | Description |
|-------|-------------|
| `extractedAt` | ISO 8601 timestamp of when extraction was run |
| `totalWords` | Count of words in the `words` array |
| `words[].word` | The final word after all backspace corrections |
| `words[].characters` | Character count of the final word |
| `words[].durationMs` | Time from first keyDown to last keyUp in milliseconds |
| `words[].mistakeCount` | Number of backspaces used while typing this word |

## Architecture

### New files

| File | Purpose |
|------|---------|
| `Sources/TypingLens/WordExtraction/ExtractedWord.swift` | `ExtractedWord` and `WordExtractionResult` model structs |
| `Sources/TypingLens/WordExtraction/WordExtractor.swift` | Pure algorithm: `[TranscriptEvent]` → `WordExtractionResult` |
| `Sources/TypingLens/WordExtraction/WordExtractionService.swift` | Reads JSONL from disk, runs extractor, writes output JSON |

### Modified files

| File | Change |
|------|--------|
| `Sources/TypingLens/Settings/SettingsRootView.swift` | Add "Extract Words" button |
| `Sources/TypingLens/Settings/SettingsViewModel.swift` | Add `onExtractWords` callback and extraction status text |

## UI

The "Extract Words" button is added to the Settings page in the existing button row alongside "Reveal in Finder" and "Clear Transcript". On press it runs extraction and shows a brief status message (e.g. "Extracted 142 words") or opens the output file in Finder.
