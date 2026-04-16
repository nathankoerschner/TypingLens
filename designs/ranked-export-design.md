# Ranked Word Export — Design

## Overview

An interpretation layer on top of the raw word extraction that normalizes, deduplicates, and ranks words by typing difficulty. The output is a ranked list of "target words" — common words the user types slowly and with mistakes — suitable for import into a typing practice tool.

## Relationship to Word Extraction

The existing `WordExtractor` produces a flat list of `[ExtractedWord]` (one entry per word typed, with duration and mistake count). The ranked export **consumes that same in-memory data** but does not depend on the JSON file output. The pipeline is:

```
transcript.jsonl → WordExtractor.extract() → [ExtractedWord]
                                                   │
                                    ┌───────────────┴───────────────┐
                                    ▼                               ▼
                          Raw JSON export                   WordRanker.rank()
                        (developer debug)                          │
                                                                   ▼
                                                      RankedWordResult (JSON)
```

### Refactor: in-memory extraction

`WordExtractionService` is split so that extraction and file I/O are separate:

- `extractInMemory() throws -> WordExtractionResult` — reads transcript JSONL, runs `WordExtractor`, returns result.
- `writeToFile(_ result: WordExtractionResult) throws` — encodes and writes to `extracted-words.json`.
- `run() throws -> WordExtractionResult` — calls both (existing behavior preserved).

The ranked export calls `extractInMemory()` directly.

## Algorithm

### 1. Case-insensitive grouping

All words are lowercased. Occurrences of `"The"`, `"the"`, and `"THE"` merge into a single group keyed by `"the"`.

### 2. Outlier removal (per-word, per-occurrence)

For each word group with **3 or more occurrences**, individual instances are removed if:

- **Slow outlier**: `durationMs > mean + 2σ` for that word group (catches context switches, distractions).
- **Error outlier**: `mistakeCount > 2 × characterCount` (more than double the letters in backspaces — likely a false start or rewrite).

Word groups with fewer than 3 occurrences keep all instances (not enough data to detect outliers).

After outlier removal, if a word group has zero remaining instances, the word is dropped entirely.

### 3. Aggregation

For each word group after outlier removal:

| Metric | Formula |
|--------|---------|
| `frequency` | Number of remaining occurrences |
| `avgDurationMs` | Mean of `durationMs` across occurrences |
| `avgMsPerChar` | `avgDurationMs / characters` |
| `avgMistakes` | Mean of `mistakeCount` across occurrences |
| `errorRate` | `avgMistakes / characters` |

### 4. Normalization (0–1 scale)

Each metric is normalized using **min-max normalization** across all word groups in the dataset. This makes scores relative — "this word is slow *for you*."

For a given metric value `v` across all words with `min` and `max`:

```
normalized = (v - min) / (max - min)
```

If `max == min` (all words have the same value), normalized value is `0.0`.

Three normalized values:

| Normalized metric | Source | Direction |
|-------------------|--------|-----------|
| `normSpeed` | `avgMsPerChar` | Higher ms = slower = worse = higher score |
| `normError` | `errorRate` | Higher error rate = worse = higher score |
| `normFrequency` | `frequency` | Higher frequency = more important to fix = higher score |

### 5. Composite score

```
compositeScore = w1 * normSpeed + w2 * normError + w3 * normFrequency
```

Default weights: `w1 = 1.0, w2 = 1.0, w3 = 1.0` (equal weighting, tunable later).

Maximum possible score: `3.0`. Minimum: `0.0`.

## Output JSON

Written to `~/Library/Application Support/TypingLens/ranked-words.json`.

```json
{
  "analyzedAt": "2026-04-14T19:00:00.000Z",
  "totalUniqueWords": 87,
  "words": [
    {
      "word": "because",
      "characters": 7,
      "frequency": 12,
      "avgMsPerChar": 185.3,
      "errorRate": 0.28,
      "compositeScore": 2.41
    },
    {
      "word": "the",
      "characters": 3,
      "frequency": 45,
      "avgMsPerChar": 92.1,
      "errorRate": 0.05,
      "compositeScore": 1.73
    }
  ]
}
```

Sorted **descending** by `compositeScore`. Top entries are the highest-priority practice targets.

### Field definitions

| Field | Description |
|-------|-------------|
| `analyzedAt` | ISO 8601 timestamp of when analysis was run |
| `totalUniqueWords` | Count of unique words in the `words` array |
| `words[].word` | Lowercased word |
| `words[].characters` | Character count |
| `words[].frequency` | Number of times the word appeared (after outlier removal) |
| `words[].avgMsPerChar` | Average milliseconds per character |
| `words[].errorRate` | Average mistakes per character |
| `words[].compositeScore` | Weighted sum of normalized speed, error, and frequency (0.0–3.0) |

## Architecture

### New files

| File | Purpose |
|------|---------|
| `Sources/TypingLens/WordExtraction/RankedWord.swift` | `RankedWord` and `RankedWordResult` model structs |
| `Sources/TypingLens/WordExtraction/WordRanker.swift` | Pure algorithm: `[ExtractedWord]` → `RankedWordResult` |
| `Sources/TypingLens/WordExtraction/RankedExportService.swift` | Calls `WordExtractionService.extractInMemory()`, runs ranker, writes output JSON |

### Modified files

| File | Change |
|------|--------|
| `Sources/TypingLens/WordExtraction/WordExtractionService.swift` | Split `run()` into `extractInMemory()` + `writeToFile()` |
| `Sources/TypingLens/Support/FileLocations.swift` | Add `rankedWordsURL` property |
| `Sources/TypingLens/Settings/SettingsRootView.swift` | Add "Export Ranked Words" button |
| `Sources/TypingLens/Settings/SettingsViewModel.swift` | Add `onExportRankedWords` callback and status text |
| `Sources/TypingLens/App/AppState.swift` | Add `rankedExportStatus` field |

## UI

A new "Export Ranked Words" button is added to the Settings page alongside the existing "Extract Words" button. On press it runs the full pipeline (extract → rank → write) and shows a brief status message (e.g., "Ranked 87 words → ranked-words.json").
