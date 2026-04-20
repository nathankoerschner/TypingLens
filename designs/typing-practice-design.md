# Typing Practice Feature — Design

## Goal

Add a **Practice Now** button to the app that:

1. gathers ranked words **in memory**
2. converts them into a Monkeytype-style practice prompt
3. opens a **separate Swift practice window**
4. runs a simple fixed-word typing game
5. does **not** write practice data or prompt data to disk

This feature should reuse the existing word extraction and ranking pipeline, but decouple extraction from file output.

---

## Product Decisions

### Confirmed decisions

- Add a **Practice Now** action: **yes**
- Decouple extraction from file writing: **yes**
- Use a **Monkeytype-like word stream seeded by ranked words**: **yes**
- Practice game should be in its **own window**: **yes**
- UI should be implemented in **SwiftUI**, hosted in a native macOS window: **yes**
- Start with **fixed word-count mode**: **yes**
- If too few ranked words exist, **repeat words to fill the target count**
- Do **not** exclude easy words beyond the existing ranking logic
- Do **not** include punctuation in the practice prompt
- Rely on existing ranked/extracted word generation to have already filtered numbers
- Do **not** persist practice results

---

## High-Level Flow

When the user presses **Practice Now**:

```text
Transcript JSONL
  → extract words in memory
  → rank words in memory
  → generate practice prompt from ranked words
  → open practice window
  → user completes fixed-length typing test
```

No practice prompt or game result is written to disk.

---

## Architecture

## Refactor: decouple extraction from file output

### Existing problem
`WordExtractionService.run()` currently both:
- extracts words from transcript
- writes `extracted-words.json`

The practice flow needs extraction without any file output.

### New API

`Sources/TypingLens/WordExtraction/WordExtractionService.swift`

Add:

- `extractInMemory() throws -> WordExtractionResult`
- `writeToFile(_ result: WordExtractionResult) throws`
- `run() throws -> WordExtractionResult`

### Intended behavior

- `extractInMemory()` reads transcript and returns extracted words only
- `writeToFile(_:)` writes an already-generated extraction result to disk
- `run()` preserves current behavior by calling both

### Example shape

```swift
struct WordExtractionService {
    func extractInMemory() throws -> WordExtractionResult
    func writeToFile(_ result: WordExtractionResult) throws
    func run() throws -> WordExtractionResult
}
```

---

## Practice prompt generation

Keep the in-memory practice model very simple.

### Minimal model

```swift
struct PracticePrompt {
    let words: [String]
}
```

This avoids introducing a heavy session model while still making the practice pipeline explicit.

### New file

`Sources/TypingLens/Practice/PracticePromptBuilder.swift`

### Responsibility
Convert `RankedWordResult` into a Monkeytype-style fixed-length word stream.

### API

```swift
struct PracticePromptBuilder {
    func build(from ranked: RankedWordResult, wordCount: Int = 50) -> PracticePrompt
}
```

---

## Prompt generation rules

### v1 defaults

- practice length: **50 words**
- source pool: **top 30 ranked words**, or fewer if not available
- output: weighted word stream using ranked words
- allow repeated words
- avoid immediate duplicates when possible

### Why this approach

This gives a Monkeytype-like feel while still emphasizing the user’s hardest words.

It is intentionally not just “top N words once each.”
Instead it is a generated stream where harder words appear more often.

### Generation algorithm

1. take ranked words in descending score order
2. select a source pool from the top ranked words
3. derive sampling weights from `compositeScore`
4. generate 15 output words by weighted sampling
5. if the chosen word matches the immediately previous word, retry when the pool has alternatives
6. if very few words exist, repeat as needed until the prompt reaches the target size

### Pseudocode

```swift
let pool = Array(ranked.words.prefix(30))
let weights = pool.map { max($0.compositeScore, 0.01) }

var output: [String] = []
while output.count < 15 {
    let next = weightedPick(from: pool, weights: weights)

    if output.last == next.word && pool.count > 1 {
        continue
    }

    output.append(next.word)
}

return PracticePrompt(words: output)
```

### Empty-state behavior

If ranked results contain no usable words:
- do not open the practice window
- show a status message in the settings UI

Suggested message:
- `No words available for practice`

---

## Practice window

The typing game should appear in its own native macOS window.

### New file

`Sources/TypingLens/Practice/PracticeWindowController.swift`

### Window approach
Use the same pattern as the settings window:
- AppKit `NSWindowController`
- SwiftUI content via `NSHostingController`

### Why
This matches the current architecture and makes window ownership simple.

### Proposed behavior

- open or reuse a single practice window
- bring app to front when opened
- focus the typing input immediately
- update the window content when a new prompt is generated

### Suggested size

Initial target size:
- approximately **900 x 520**

This is large enough to feel like a proper typing surface.

### Example API

```swift
final class PracticeWindowController: NSWindowController {
    func show(prompt: PracticePrompt)
}
```

---

## Practice UI

### New files

- `Sources/TypingLens/Practice/PracticeRootView.swift`
- `Sources/TypingLens/Practice/PracticeViewModel.swift`

### UX goals
The UI should feel inspired by Monkeytype:
- minimal chrome
- centered content
- dark theme
- large multi-line word area
- subdued future text
- visible active word and active character
- clean live metrics

### Layout

#### Top row
Display lightweight stats:
- WPM
- accuracy
- progress (`12 / 50`)

#### Center
Render the prompt word stream:
- previously completed words shown in completed state
- current word highlighted
- correct typed characters styled differently from incorrect typed characters
- future words muted

#### Bottom row
Controls:
- restart same prompt
- new prompt
- close window

---

## Input handling

To achieve the Monkeytype-like feel, the app should not rely on a standard visible text field as the main UI.

### Recommended approach

- keep a hidden or visually minimized focusable text input
- render the typing state manually in SwiftUI

### Why
This allows the app to control:
- character coloring
- incorrect character styling
- active word highlight
- current cursor position appearance

This is the simplest way to get a custom typing-game presentation while still using standard SwiftUI focus/input behavior.

---

## Game mode

### v1 mode
Use a **fixed 50-word test**.

### Why
This is simpler than timed mode and fits the generated prompt model directly.

### Completion behavior
The test ends when all 50 words have been submitted.

At completion, the UI can continue showing:
- final WPM
- final accuracy
- restart / new prompt actions

No persistence is needed.

---

## Practice state

A heavy domain/session model is not required for v1.

Keep state local to the practice view model.

### Example shape

```swift
final class PracticeViewModel: ObservableObject {
    @Published var promptWords: [String]
    @Published var currentInput: String
    @Published var submittedWords: [String]
    @Published var startedAt: Date?
    @Published var finishedAt: Date?

    var currentWordIndex: Int { submittedWords.count }
    var isFinished: Bool { currentWordIndex >= promptWords.count }
}
```

This is enough to support:
- input tracking
- progress
- WPM
- accuracy
- restart
- new prompt

---

## App integration

## New action

Add a new action alongside existing extraction/ranking actions:

```swift
func practiceNowRequested()
```

### Location
`Sources/TypingLens/App/LoggingCoordinator.swift`

### Responsibility
`practiceNowRequested()` should:

1. create/use `WordExtractionService`
2. call `extractInMemory()`
3. rank words using `WordRanker`
4. build a `PracticePrompt` using `PracticePromptBuilder`
5. open the practice window via an injected callback or owned controller

### Example flow

```swift
let extraction = try extractionService.extractInMemory()
let ranked = ranker.rank(extraction.words)
let prompt = promptBuilder.build(from: ranked, wordCount: 15)
onOpenPractice(prompt)
```

### Error handling
If anything fails:
- do not open the practice window
- update UI status with a human-readable error

---

## UI integration

### Settings UI
Add a new button:
- `Practice Now`

### Files to modify

- `Sources/TypingLens/Settings/SettingsRootView.swift`
- `Sources/TypingLens/Settings/SettingsViewModel.swift`
- `Sources/TypingLens/Settings/SettingsWindowController.swift`
- `Sources/TypingLens/App/TypingLensApp.swift`

### Callback addition

Add:
- `onPracticeNow: () -> Void`

through the existing settings callback chain.

---

## App state

No need to store the whole practice prompt in `AppState`.

A lightweight status field is enough.

### Suggested addition
`Sources/TypingLens/App/AppState.swift`

```swift
@Published var practiceStatus: String?
```

Use this for messages like:
- `No words available for practice`
- `Practice generation failed: ...`

The actual prompt and live typing state should stay inside the practice window/view model.

---

## Ownership of the practice window

Preferred approach:
- `TypingLensApp` creates and owns a single `PracticeWindowController`
- `LoggingCoordinator` receives a closure to open practice

### Example

```swift
let loggingCoordinator = LoggingCoordinator(
    ...,
    onOpenPractice: { prompt in
        practiceWindowController.show(prompt: prompt)
    }
)
```

### Why
This keeps window lifecycle in the app layer while keeping orchestration in the coordinator.

---

## Files to add

- `Sources/TypingLens/Practice/PracticePromptBuilder.swift`
- `Sources/TypingLens/Practice/PracticeRootView.swift`
- `Sources/TypingLens/Practice/PracticeViewModel.swift`
- `Sources/TypingLens/Practice/PracticeWindowController.swift`

## Files to modify

- `Sources/TypingLens/WordExtraction/WordExtractionService.swift`
- `Sources/TypingLens/App/LoggingCoordinator.swift`
- `Sources/TypingLens/App/AppState.swift`
- `Sources/TypingLens/Settings/SettingsRootView.swift`
- `Sources/TypingLens/Settings/SettingsViewModel.swift`
- `Sources/TypingLens/Settings/SettingsWindowController.swift`
- `Sources/TypingLens/App/TypingLensApp.swift`

---

## v1 Summary

The first version of the feature should:

- add a **Practice Now** button
- extract and rank words **entirely in memory**
- generate a **50-word Monkeytype-style prompt** from ranked words
- open a **dedicated practice window**
- render a custom SwiftUI typing surface with hidden text input
- track basic live metrics like WPM, accuracy, and progress
- avoid writing prompt/results to disk

This keeps the feature aligned with the current architecture while remaining intentionally simple for an initial implementation.
