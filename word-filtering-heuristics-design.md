# Word Filtering & Spelling Heuristics — Design

## Overview

Add a local deterministic interpretation stage between raw word extraction and ranking.

Its job is to take each extracted token and decide whether to:

1. **accept** it as a common English word
2. **correct** it to the most likely common English word and add an inferred spelling penalty
3. **drop** it as gibberish, uncommon, non-English, proper-noun-like, or too ambiguous to trust

This stage is intentionally **not** LLM-based. It uses a local lexicon, typo-distance scoring, and explicit heuristics for dropping gibberish.

---

## Goals

- Run **completely locally**
- Keep only **common English words**
- Drop **uncommon words**
- Drop **names / proper nouns**
- Never rewrite a token that is already a valid lexicon word
- Correct obvious misspellings like `teh -> the`
- Drop obvious garbage like `jjjjkjj`
- Keep transcript-derived mistakes separate from inferred spelling penalties

---

## Non-Goals

- Context-aware sentence correction
- Semantic disambiguation
- Proper noun support
- Multilingual support
- Recovering rare technical words, product names, or slang
- Using a local or remote LLM

---

## Pipeline Placement

Current pipeline:

```text
Transcript -> WordExtractor -> [ExtractedWord] -> WordRanker
```

New pipeline:

```text
Transcript
  -> WordExtractor
  -> [ExtractedWord]
  -> WordInterpreter
  -> [InterpretedWord]
  -> WordRanker
```

The interpretation stage runs before grouping/ranking so that:

- corrected spellings merge into the intended target word
- dropped gibberish never affects rankings
- inferred spelling penalties can contribute to difficulty scoring

---

## Lexicon

### Source format

Use a simple local newline-delimited text file of common English words.

Example:

```text
the
and
to
of
a
in
is
that
because
...
```

### Lexicon policy

- English only
- Lowercase only
- No names / proper nouns
- No uncommon words
- No technical vocabulary unless it is also common English
- Target size: **~30,000 words**

### Lexicon semantics

A token is considered a valid word only if its lowercase normalized form exists in this lexicon.

Because the lexicon is intentionally limited to common words:

- uncommon words are dropped
- names are dropped
- many technical terms are dropped

This is expected and desired for V1.

---

## Interpretation Outcomes

Each extracted token resolves to one of three outcomes.

### 1. Accepted

The token is already a valid lexicon word.

Examples:

- `the` -> accept `the`
- `because` -> accept `because`

Behavior:

- keep the word as-is after normalization
- inferred spelling penalty = `0`
- do not attempt correction

### 2. Corrected

The token is not a lexicon word, but it is a high-confidence misspelling of a lexicon word.

Examples:

- `teh` -> correct to `the`
- `becuase` -> correct to `because`

Behavior:

- replace token with corrected lexicon word
- inferred spelling penalty = **`1`**
- keep transcript-derived mistake count separate internally

### 3. Dropped

The token is not accepted or corrected with enough confidence.

Examples:

- `jjjjkjj` -> drop
- uncommon word not in lexicon -> drop
- proper name not in lexicon -> drop
- ambiguous low-confidence non-word -> drop

Behavior:

- exclude from downstream ranking entirely

---

## Normalization

Before interpretation, normalize each token:

1. lowercase it
2. normalize smart apostrophes to `'`
3. trim leading/trailing apostrophes defensively

The extractor already performs some cleanup, but the interpretation layer should normalize again to make lexicon lookup stable.

---

## Hard Rule: Never Correct Valid Words

If a normalized token is already in the lexicon, it must be accepted immediately.

Do **not** attempt to reinterpret valid words as other words.

Examples:

- `form` stays `form`
- `from` stays `from`

This prevents false positives caused by lack of sentence context.

---

## Candidate Search

For tokens not found in the lexicon, search for candidate corrections among lexicon words.

### Distance metric

Use **Damerau-Levenshtein distance** so common typing transpositions are handled naturally.

This is important for cases like:

- `teh` -> `the`
- `wrod` -> `word`

### Candidate constraints

Only consider candidates within a conservative edit-distance threshold.

Suggested V1 thresholds:

- token length `2...4` -> max distance `1`
- token length `5...10` -> max distance `2`
- token length `11+` -> max distance `2`

These thresholds are intentionally conservative.

### Candidate selection

Among matching candidates, choose the best one using:

1. lowest edit distance
2. earlier appearance in the lexicon file as a proxy for commonness

Because the lexicon file is ordered by commonness, earlier words win ties.

---

## Confidence Gate

A token should be corrected only if the best candidate is sufficiently trustworthy.

### Correct if all are true

1. token is **not** already in the lexicon
2. at least one candidate exists within allowed edit distance
3. best candidate is clearly the strongest available match
4. token does not trip gibberish-drop heuristics strongly enough to force rejection

### Drop otherwise

If confidence is weak or ambiguous, drop the token rather than guessing.

### Aggressiveness

V1 uses **moderate** correction aggressiveness:

- common typos should correct
- borderline or ambiguous cases should drop

The system should prefer **false negatives over false positives**.

---

## Gibberish-Dropping Heuristics

These heuristics exist specifically to identify tokens that look like garbage rather than failed attempts at a real word.

They are **drop heuristics**, not general scoring features.

They should be implemented and documented as such.

### Principle

Use **light explicit heuristics** for nonsense patterns, then rely on candidate confidence for the rest.

We do **not** want a large complicated rule engine. We only want a few cheap checks that catch obviously bad tokens early.

### V1 heuristic categories

#### 1. Repetition-based gibberish

Drop tokens with extreme repeated-character behavior.

Examples:

- `jjjjkjj`
- `aaaaaaa`
- `zzzzxzz`

Possible signals:

- very long run of the same character
- extremely low unique-character count relative to length
- one character dominating most of the token

#### 2. No-vowel nonsense

Drop longer tokens with no standard vowel pattern when they do not resemble common English forms.

Examples:

- `jjjjkjj`
- `qwrtyp`

This should be conservative so short valid forms are not accidentally removed.

#### 3. Low-structure / keyboard-smash patterns

Drop tokens that appear mechanically random or smash-typed rather than word-like.

Examples:

- `asdfasdf`
- `qwertyu`
- `jjjjkjj`

Possible signals:

- repetitive chunks
- highly unnatural character distribution
- no plausible nearby lexicon candidate

### Important implementation note

These heuristics are only for **dropping likely gibberish words**.

They are not intended to infer the intended word.
The intended word should come from the candidate search + confidence gate.

### Final V1 positioning

Use:

- **some explicit heuristics** for gibberish dropping
- **strong candidate threshold** for correction

This keeps the role of heuristics clear and limited.

---

## Error Model

Keep two error sources separate internally.

### 1. Transcript mistakes

These come directly from extraction:

- backspaces
- in-word corrections
- other observed mistake signals already captured by `mistakeCount`

### 2. Inferred spelling penalty

These come from the interpretation layer when a non-word is corrected to a lexicon word.

### V1 penalty rule

Every corrected token gets:

```text
inferredSpellingPenalty = 1
```

This is fixed for V1.

It does not attempt to equal literal edit distance.
It is simply a signal that the user likely intended a real word but typed it incorrectly.

---

## Data Model

Current extracted model:

```swift
struct ExtractedWord {
    let word: String
    let characters: Int
    let durationMs: Double
    let mistakeCount: Int
}
```

Add an interpreted form:

```swift
struct InterpretedWord {
    let originalWord: String
    let normalizedWord: String
    let characters: Int
    let durationMs: Double
    let transcriptMistakeCount: Int
    let inferredSpellingPenalty: Int
    let wasCorrected: Bool
}
```

### Notes

- `normalizedWord` is the accepted or corrected lexicon word
- dropped words do not appear in the output collection
- `characters` should reflect the final normalized word

---

## Ranking Integration

Ranking should operate on interpreted words, not raw extracted tokens.

When computing error-based ranking metrics, combine the two mistake sources at scoring time:

```text
totalMistakes = transcriptMistakeCount + inferredSpellingPenalty
```

This preserves separation internally while keeping ranking simple.

### Why this matters

- `teh` corrected to `the` should count toward difficulty of `the`
- gibberish should not produce its own ranked entry
- spelling failures should increase difficulty without pretending they were transcript backspaces

---

## Example Behavior

### Example 1: obvious typo

Input token:

```text
teh
```

Process:

- not in lexicon
- candidate `the` found at close distance
- high confidence

Output:

```text
corrected -> the
inferredSpellingPenalty = 1
```

### Example 2: common misspelling

Input token:

```text
becuase
```

Process:

- not in lexicon
- candidate `because` found
- good distance and strong candidate

Output:

```text
corrected -> because
inferredSpellingPenalty = 1
```

### Example 3: valid word

Input token:

```text
form
```

Process:

- exact lexicon hit
- do not attempt reinterpretation

Output:

```text
accepted -> form
inferredSpellingPenalty = 0
```

### Example 4: gibberish

Input token:

```text
jjjjkjj
```

Process:

- not in lexicon
- trips gibberish-drop heuristics and/or lacks a strong nearby candidate

Output:

```text
dropped
```

### Example 5: uncommon word

Input token:

```text
fjord
```

If not in the common-word lexicon:

```text
dropped
```

This is expected in V1.

---

## Proposed Types

### Decision type

```swift
enum WordDecision {
    case accepted(word: String)
    case corrected(original: String, corrected: String, inferredPenalty: Int)
    case dropped(original: String, reason: DropReason)
}
```

### Drop reasons

```swift
enum DropReason {
    case notInLexicon
    case lowConfidenceCorrection
    case gibberishHeuristic
}
```

### Interpreter result

```swift
struct WordInterpretationResult {
    let words: [InterpretedWord]
    let correctedCount: Int
    let droppedCount: Int
}
```

These structures are useful for debugging and tests even if only `[InterpretedWord]` is used in production flow.

---

## Proposed File Layout

### New files

- `Sources/TypingLens/WordExtraction/WordInterpreter.swift`
- `Sources/TypingLens/WordExtraction/WordLexicon.swift`
- `Sources/TypingLens/WordExtraction/InterpretedWord.swift`
- `Sources/TypingLens/WordExtraction/DamerauLevenshtein.swift`
- `Resources/common-words-en.txt` or equivalent bundled word list

### Modified files

- `Sources/TypingLens/WordExtraction/WordRanker.swift`
  - consume interpreted words or preprocess extracted words before grouping
- `Sources/TypingLens/WordExtraction/RankedExportService.swift`
  - if needed, wire in interpreter dependency

---

## Testing Strategy

### Lexicon acceptance tests

- exact common words are accepted
- uncommon words are dropped
- names are dropped

### Correction tests

- `teh -> the`
- `becuase -> because`
- `wrod -> word`
- already-valid words are never rewritten

### Gibberish tests

- `jjjjkjj` drops
- `asdfasdf` drops
- repetitive-noise tokens drop

### Ambiguity tests

- low-confidence tokens drop instead of guessing
- valid words remain untouched

### Ranking integration tests

- corrected words merge under corrected target word
- inferred penalty contributes to error rate
- dropped words do not appear in ranked output

---

## Tuning Guidance

If V1 under-corrects:

- slightly relax edit-distance thresholds
- slightly relax candidate confidence requirements

If V1 over-corrects:

- tighten confidence threshold
- strengthen gibberish-drop heuristics
- reduce allowable edit distance for short tokens

The intended bias is conservative:

- dropping uncertain tokens is acceptable
- incorrect correction is worse than omission

---

## Summary

V1 introduces a deterministic local word interpretation layer that:

- uses a simple local **30k common English word list**
- accepts exact common words
- corrects obvious misspellings with **`inferredSpellingPenalty = 1`**
- drops gibberish, uncommon words, names, and ambiguous non-words
- keeps transcript mistakes and inferred spelling penalties separate internally
- feeds corrected/common words into ranking so practice targets reflect intended words rather than raw noisy tokens
