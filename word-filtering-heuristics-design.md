# Word Filtering & Typo Resolution — Revised Design

## Overview

Revise the word interpretation pipeline so it is explicitly split into two stages:

1. **Exact lexicon pass** — fast membership-only classification
2. **Unknown-token resolution pass** — typo correction or drop, applied only to tokens that failed exact lookup

This design keeps the common case cheap and isolates more expensive typo logic to a much smaller set of tokens.

---

## Goals

- Make the primary interpretation path very fast
- Use exact lexicon membership as the default acceptance rule
- Avoid expensive fuzzy matching on already-valid words
- Restrict typo handling to unknown tokens only
- Preserve deterministic offline behavior
- Keep ranking and practice generation based on the same interpreted vocabulary

---

## Non-Goals

- Context-aware spelling correction
- Sentence-level disambiguation
- LLM-backed interpretation
- Multilingual support
- Full-dictionary fuzzy search in the hot path

---

## Revised Pipeline

Current intended pipeline:

```text
Transcript
  -> WordExtractor
  -> [ExtractedWord]
  -> WordInterpreter
  -> [InterpretedWord]
  -> WordRanker
```

Revised internal structure of `WordInterpreter`:

```text
[ExtractedWord]
  -> normalization
  -> Pass 1: Exact lexicon classification
      -> accepted words
      -> unknown words
  -> Pass 2: Unknown-token resolution
      -> corrected words
      -> dropped words
  -> [InterpretedWord]
```

The key change is that typo logic is no longer part of the default path for every token.

---

## Pass 1: Exact Lexicon Classification

### Rule

After normalization, check whether the token exists in the lexicon.

```text
if lexicon.contains(normalizedToken)
    accept
else
    mark as unknown
```

### Data structure

Exact lookup should use a hash-based membership structure:

```swift
Set<String>
```

This is the primary performance path.

### Notes

- This pass should be extremely cheap
- This is expected to handle the majority of normal transcript tokens
- Valid words must short-circuit here and never enter typo resolution

### Examples

- `the` -> accepted
- `because` -> accepted
- `form` -> accepted
- `from` -> accepted

---

## Pass 2: Unknown-Token Resolution

Only tokens that failed exact lexicon lookup should be processed here.

### Input

A smaller set of normalized unknown tokens.

### Output

Each unknown token resolves to one of:

- corrected
- dropped

### Important design constraint

This pass should preferably run on **unique unknown tokens**, not every occurrence.

That means:

- `teh` appearing 50 times should be analyzed once
- `jjjjkjj` appearing 20 times should be analyzed once
- the decision is then reused for all occurrences

This dramatically reduces cost.

---

## Typo Resolution Strategies

The second-stage typo resolver can evolve independently from the exact lexicon pass.

### Acceptable strategies

#### Option A: Curated typo map

```text
teh -> the
becuase -> because
wrod -> word
```

Behavior:

```text
if typoMap[unknownToken] exists
    correct
else
    drop
```

Pros:
- very fast
- deterministic
- low complexity

Cons:
- limited coverage

#### Option B: Indexed spell correction

If broader correction is needed, use an index designed for typo lookup, such as:

- SymSpell-style delete index
- BK-tree

This should be implemented as a separate resolver behind the unknown-token stage, not as an inline full-lexicon scan.

Pros:
- broader typo coverage

Cons:
- more implementation complexity

### Strategy explicitly discouraged

Avoid full lexicon approximate matching for every unknown token in the ranking/export hot path.

That approach caused the performance issues observed in practice.

---

## Suggested V1 Behavior

Recommended V1 behavior:

1. exact lexicon acceptance
2. optional small typo map for common misspellings
3. otherwise drop unknown tokens

This gives:

- good performance
- deterministic behavior
- support for very common typos
- no large fuzzy-search cost

### Examples

- `the` -> accept
- `teh` -> correct via typo map
- `because` -> accept
- `becuase` -> correct via typo map
- `jjjjkjj` -> drop
- `xqplm` -> drop
- uncommon token not in lexicon -> drop

---

## Normalization

Normalization should still happen before any pass:

1. lowercase
2. normalize smart apostrophes to `'`
3. trim leading/trailing apostrophes

This ensures exact lexicon lookup is stable.

---

## Data Model

No major change is required to the interpreted-word model.

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

### Decision model

```swift
enum WordDecision {
    case accepted(word: String)
    case corrected(original: String, corrected: String, inferredPenalty: Int)
    case dropped(original: String, reason: DropReason)
}
```

---

## Performance Principles

### 1. Exact match first

Most words should be handled by a cheap exact membership check.

### 2. Unknowns only

Typo logic should run only on words that failed exact lookup.

### 3. Unique unknown tokens

Unknown-token analysis should be cached by normalized token.

### 4. Resolver isolation

The typo resolver should be a separate stage or component so it can be changed without affecting the fast exact-match path.

---

## Proposed Internal Architecture

One clean structure would be:

```swift
struct WordInterpreter {
    let lexicon: WordLexicon
    let typoResolver: TypoResolver?

    func interpret(_ words: [ExtractedWord]) -> WordInterpretationResult
}
```

Where `TypoResolver` is responsible only for unknown tokens:

```swift
protocol TypoResolver {
    func resolve(_ token: String) -> TypoResolution
}
```

Example resolution type:

```swift
enum TypoResolution {
    case corrected(String, inferredPenalty: Int)
    case dropped(DropReason)
}
```

This keeps responsibilities clear:

- `WordLexicon` answers exact membership
- `WordInterpreter` orchestrates
- `TypoResolver` handles unknown-token correction/drop logic

---

## Ranking Implications

Ranking remains downstream from interpretation.

- accepted words rank normally
- corrected words merge under the corrected normalized word
- dropped words never reach the ranker
- inferred spelling penalties still contribute to `errorRate`

No change is needed to the ranking model beyond consuming interpreted words.

---

## Testing Strategy

### Exact lexicon tests

- exact common word is accepted
- valid words never enter typo correction
- normalization still works correctly

### Unknown-token stage tests

- known typo map entries correct correctly
- unknown non-typo tokens drop
- gibberish drops
- repeated unknown tokens are resolved once and reused

### Integration tests

- ranked export merges accepted and corrected words correctly
- dropped unknown words do not appear in ranked output
- practice generation sees the same interpreted vocabulary

---

## Migration Plan

1. Keep normalization in `WordInterpreter`
2. Make exact lexicon classification the first pass
3. Move typo logic behind an unknown-token-only resolver interface
4. Initially implement the resolver as:
   - typo map, or
   - no-op drop-only resolver
5. Preserve `InterpretedWord` and ranking integration
6. Add tests that prove valid words short-circuit before typo handling

---

## Summary

The revised design makes the pipeline intentionally two-stage:

- **Pass 1:** exact lexicon membership for all tokens
- **Pass 2:** typo resolution only for unknown tokens

This keeps the common case fast, makes the architecture clearer, and avoids expensive fuzzy correction work in the main ranking/export path.
