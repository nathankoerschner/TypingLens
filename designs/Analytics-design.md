# Analytics Feature — Design

## Goal

Add a dedicated **Analytics** page/window where the user can see their **weakest words in ranked order**, using the existing composite weakness score, along with supporting detail about:

- number of errors
- number of misspellings
- overall WPM
- times typed
- common misspelled variants for a selected word

This feature should build on the app’s existing transcript → extraction → interpretation → ranking pipeline.

---

## Confirmed Product Decisions

### Windowing
- Analytics should open in a **separate native macOS window**
- It should follow the same general ownership pattern as the existing practice window

### Ranking
- Words should be ordered by the existing **composite score** from the ranking pipeline
- This score remains the app’s definition of “weakest words”

### v1 UI shape
- Main content should be a **ranked table**
- Selecting a row should reveal a **detail panel** for that word

### v1 metrics to show
Each row should include:
- rank
- word
- weakness score
- errors
- misspellings
- WPM
- times typed

The detail panel should include:
- normalized/canonical word
- average WPM
- total errors
- total misspellings
- average ms/char
- occurrence count
- common misspelled variants and counts

### Scope
- Use **all available transcript history** for v1
- No charts, trend lines, time filters, or export in v1

---

## Proposed UX

## Analytics table

The analytics window should present a ranked table like:

| Rank | Word | Weakness Score | Errors | Misspellings | WPM | Times Typed |
|------|------|----------------|--------|--------------|-----|-------------|
| 1 | because | 2.41 | 18 | 6 | 32.4 | 12 |
| 2 | their | 2.10 | 10 | 4 | 41.8 | 9 |
| 3 | separate | 1.98 | 9 | 5 | 36.2 | 7 |

### Table behavior
- sorted descending by `weaknessScore` / `compositeScore`
- first row may be auto-selected when data is available
- clicking a row updates the detail panel
- empty state should clearly explain when there is not enough data

## Detail panel

When the user selects a word, show a detail panel with:

- canonical word
- average WPM
- average ms/char
- total errors
- total misspellings
- times typed
- common misspelled variants, for example:
  - `becuase` → 3
  - `becausee` → 2

### Empty detail state
If no row is selected, show a placeholder such as:
- `Select a word to view details`

---

## Definitions

To keep the metrics consistent with the current codebase, use these definitions.

### Weakness score
Use the existing `compositeScore` from `WordRanker`.

This score already combines:
- typing speed difficulty
- error rate
- frequency importance

### Errors
`Errors` should mean the total number of mistakes associated with the normalized word.

For each interpreted occurrence, this should include:
- `transcriptMistakeCount`
- plus `inferredSpellingPenalty`

Then aggregate across all occurrences of the normalized word.

### Misspellings
`Misspellings` should mean the number of occurrences where the typed token was corrected to the normalized/canonical word.

In other words:
- count interpreted words where `wasCorrected == true`
- grouped under the corrected `normalizedWord`

### Times typed
This should be the occurrence count for the normalized word after interpretation.

### Overall WPM
Derive per-word WPM from `avgMsPerChar`.

Formula:

```swift
wpm = 12000 / avgMsPerChar
```

Explanation:
- 5 chars = 1 standard word
- `avgMsPerChar * 5` = milliseconds per standard word
- `60000 / (avgMsPerChar * 5)` = WPM

If `avgMsPerChar <= 0`, show `0`.

### Misspelled variants
Track the original typed forms that were corrected into the canonical word.

Example:
- typed `becuase`
- interpreted/corrected to `because`
- increment variant count for `becuase` under canonical word `because`

Only corrected variants should appear in the misspelling list.

---

## Data Model

## Analytics result model

Add a dedicated analytics model.

### Suggested shape

```swift
struct AnalyticsResult: Equatable, Codable {
    let analyzedAt: String
    let totalUniqueWords: Int
    let words: [AnalyticsWord]
}

struct AnalyticsWord: Equatable, Codable, Identifiable {
    let id: String
    let rank: Int
    let word: String
    let characters: Int
    let frequency: Int
    let totalErrors: Int
    let misspellingCount: Int
    let avgMsPerChar: Double
    let overallWPM: Double
    let compositeScore: Double
    let misspellings: [MisspellingVariant]
}

struct MisspellingVariant: Equatable, Codable, Identifiable {
    let id: String
    let typed: String
    let count: Int
}
```

### Notes
- `id` can be the canonical word string
- `rank` should reflect the sorted order in the final output
- `frequency` is the number shown to users as `Times Typed`
- `misspellings` should be sorted descending by count, then alphabetically for stable display

---

## Data Pipeline

The analytics feature should reuse the same core pipeline already used for ranked export and practice.

```text
transcript.jsonl
  → WordExtractionService.extractInMemory()
  → WordInterpreter.interpret(...)
  → WordRanker.rank(...)
  → AnalyticsService.aggregate(...)
  → AnalyticsResult
  → Analytics window
```

## Why this approach

This keeps analytics aligned with the rest of the app:
- same transcript source
- same interpretation rules
- same ranking definition
- same corrected-word logic

That means the user’s analytics and practice targets stay consistent.

---

## Analytics aggregation logic

Create a dedicated analytics service that combines interpreted-word details with ranked-word output.

## Inputs

The analytics service should use:
- `WordExtractionService.extractInMemory()`
- `WordInterpreter.interpret(...)`
- `WordRanker.rank(...)`

## Aggregation steps

### 1. Extract and interpret words
Generate interpreted words using the existing interpretation layer.

This gives access to:
- original token typed
- normalized canonical word
- transcript mistake count
- inferred spelling penalty
- whether the word was corrected

### 2. Rank words
Run `WordRanker.rank(...)` on the interpreted words.

This provides:
- canonical ordering
- `avgMsPerChar`
- `errorRate`
- `frequency`
- `compositeScore`

### 3. Aggregate analytics-only fields
For each canonical word in the ranked output, compute:

- `totalErrors`
- `misspellingCount`
- `overallWPM`
- `misspelling variants`

### 4. Preserve ranked order
Build analytics rows in the same order as `ranked.words` so the displayed rank matches the existing composite-score ordering.

---

## Detailed field derivation

For each canonical word group:

### totalErrors

```swift
sum(transcriptMistakeCount + inferredSpellingPenalty)
```

across all interpreted occurrences belonging to that normalized word.

### misspellingCount

```swift
count(where: wasCorrected == true)
```

across all interpreted occurrences belonging to that normalized word.

### overallWPM

```swift
avgMsPerChar > 0 ? 12000 / avgMsPerChar : 0
```

using the value from the ranked output.

### misspellings
For corrected occurrences only:
- group by `originalWord`
- count occurrences
- produce `[MisspellingVariant]`

Suggested sort:
1. descending count
2. ascending typed string

---

## Service Design

## New file

`Sources/TypingLens/Analytics/AnalyticsService.swift`

## Responsibility
Produce an `AnalyticsResult` fully in memory.

## Suggested API

```swift
struct AnalyticsService {
    let fileLocations: FileLocations
    let extractionService: WordExtractionService
    let interpreter: WordInterpreter
    let ranker: WordRanker

    func analyze() throws -> AnalyticsResult
}
```

## Behavior
`analyze()` should:
1. extract transcript words in memory
2. interpret them
3. rank them
4. compute analytics rows
5. return a fully built `AnalyticsResult`

### Empty-state behavior
If there are no usable words:
- return an `AnalyticsResult` with `totalUniqueWords == 0`
- UI should show an empty-state message rather than an empty detail panel

Suggested empty-state copy:
- `No analytics available yet`
- `Start typing and come back after more transcript data has been collected`

---

## UI Design

## Window approach
Use a dedicated native window, similar to the practice window.

## New files

- `Sources/TypingLens/Analytics/AnalyticsRootView.swift`
- `Sources/TypingLens/Analytics/AnalyticsViewModel.swift`
- `Sources/TypingLens/Analytics/AnalyticsWindowController.swift`

## Layout

Recommended two-pane layout:

### Left/main pane
Ranked table of weakest words.

Columns:
- Rank
- Word
- Weakness Score
- Errors
- Misspellings
- WPM
- Times Typed

### Right/detail pane
Selected word details.

Sections:
- summary stats
- misspelled variants list

### Header
A simple header can include:
- title: `Analytics`
- subtitle with analyzed-at timestamp or summary count
- refresh button
- close button optional if needed at view level

---

## View model design

## Suggested state

```swift
final class AnalyticsViewModel: ObservableObject {
    @Published private(set) var result: AnalyticsResult?
    @Published var selectedWordID: String?
    @Published private(set) var isLoading: Bool
    @Published private(set) var errorMessage: String?

    let onRefresh: () -> Void
}
```

## Responsibilities
- hold the latest analytics result
- manage selection state
- expose the selected row for the detail panel
- surface empty/loading/error states cleanly

## Selection behavior
- if analytics data loads and nothing is selected, auto-select the first word
- if the selected word disappears after refresh, fall back to the first available word

---

## Window controller design

## Suggested API

```swift
final class AnalyticsWindowController: NSWindowController {
    func show(result: AnalyticsResult)
}
```

## Behavior
- create or reuse one analytics window
- update content when a fresh result is generated
- bring app to front when opened
- preserve window instance across opens

### Suggested size
Initial target size:
- around `980 x 620`

This gives enough room for a useful table plus detail panel.

---

## App Integration

## Coordinator action

Add a new action to `LoggingCoordinator`:

```swift
func showAnalyticsRequested()
```

## Responsibility
This action should:
1. create/use `AnalyticsService`
2. run analytics generation
3. handle empty/error cases
4. open the analytics window with the result

### Example flow

```swift
let service = AnalyticsService(fileLocations: fileLocations)
let result = try service.analyze()

if result.words.isEmpty {
    appState.analyticsStatus = "No analytics available yet"
} else {
    appState.analyticsStatus = nil
    onOpenAnalytics(result)
}
```

## App state

Add a lightweight status field to `AppState`:

```swift
@Published var analyticsStatus: String?
```

Use it for messages like:
- `No analytics available yet`
- `Analytics generation failed: ...`

---

## Settings and menu integration

## Settings
Add an `Open Analytics` button to the Settings UI.

## Menu bar
Add an `Analytics` or `Open Analytics` item to the menu bar menu.

## Callback plumbing
Thread a new callback through the existing chain, similar to practice:

- `SettingsViewModel`
- `SettingsWindowController`
- `TypingLensApp`
- `LoggingCoordinator`

Suggested callback name:
- `onOpenAnalytics: () -> Void`

---

## Ownership

Preferred ownership pattern:
- `TypingLensApp` owns a single `AnalyticsWindowController`
- `LoggingCoordinator` receives a closure for opening analytics

Example:

```swift
let loggingCoordinator = LoggingCoordinator(
    ...,
    onOpenAnalytics: { result in
        analyticsWindowController.show(result: result)
    }
)
```

This matches the existing separation of concerns:
- app layer owns windows
- coordinator owns orchestration
- services own data generation

---

## Files to add

- `Sources/TypingLens/Analytics/AnalyticsService.swift`
- `Sources/TypingLens/Analytics/AnalyticsRootView.swift`
- `Sources/TypingLens/Analytics/AnalyticsViewModel.swift`
- `Sources/TypingLens/Analytics/AnalyticsWindowController.swift`
- `Sources/TypingLens/Analytics/AnalyticsModels.swift`

## Files to modify

- `Sources/TypingLens/App/LoggingCoordinator.swift`
- `Sources/TypingLens/App/AppState.swift`
- `Sources/TypingLens/Settings/SettingsRootView.swift`
- `Sources/TypingLens/Settings/SettingsViewModel.swift`
- `Sources/TypingLens/Settings/SettingsWindowController.swift`
- `Sources/TypingLens/App/TypingLensApp.swift`
- `Sources/TypingLens/MenuBar/MenuBarController.swift`

---

## v1 Summary

The first version of Analytics should:

- open in a **separate native macOS window**
- show the user’s **weakest words in ranked order**
- use the existing **composite score** as the ranking source
- display a ranked table with:
  - word
  - weakness score
  - errors
  - misspellings
  - WPM
  - times typed
- show a detail panel with:
  - canonical word
  - average WPM
  - average ms/char
  - total errors
  - total misspellings
  - occurrence count
  - common misspelled variants
- reuse the current transcript → extract → interpret → rank pipeline
- avoid adding charts, filtering, or export in v1

This keeps the feature aligned with the current architecture while giving users a clear, actionable view into the words they struggle with most.
