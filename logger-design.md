# TypingLens Logger Design

## Product summary

**TypingLens** is a macOS menu bar app that globally captures keyboard activity and writes it to a single local transcript file.

It should:

- log **global** keyboard activity across the system
- capture both **`keyDown`** and **`keyUp`**
- write events into one append-only **JSONL transcript**
- let the user:
  - enable logging
  - disable logging
  - open settings
  - reveal transcript in Finder
  - clear transcript
- handle permission onboarding clearly
- enter an explicit error state if the transcript cannot be written

---

## Product behavior

### Logging behavior
When logging is enabled:

- app captures all keyboard events globally
- app writes every event to:
  - `~/Library/Application Support/TypingLens/transcript.jsonl`
- app includes enough metadata for downstream reconstruction:
  - strict event order
  - key identity
  - modifier state
  - repeat state
  - printable character values where available

When logging is disabled:

- event capture stops
- transcript remains untouched

---

## Transcript behavior

### Path

```text
~/Library/Application Support/TypingLens/transcript.jsonl
```

### Rules

- one file only
- append forever
- no rotation
- no reset on launch
- if missing, recreate automatically on next write
- **Clear Transcript** truncates the file to empty
- if logging is active and user clears transcript, logging continues immediately into the emptied file

---

## Event schema

### Required fields
Each line in `transcript.jsonl` is one JSON object with at least:

- `seq`: monotonic sequence number
- `ts`: timestamp in ISO 8601 UTC with fractional seconds
- `type`: `keyDown` or `keyUp`
- `keyCode`
- `characters`
- `charactersIgnoringModifiers`
- `modifiers`
- `isRepeat`

### Optional field

- keyboard layout identifier, if available

### Example

```json
{"seq":1,"ts":"2026-04-14T12:01:03.510123Z","type":"keyDown","keyCode":0,"characters":"A","charactersIgnoringModifiers":"a","modifiers":["shift"],"isRepeat":false}
{"seq":2,"ts":"2026-04-14T12:01:03.590441Z","type":"keyUp","keyCode":0,"characters":"A","charactersIgnoringModifiers":"a","modifiers":["shift"],"isRepeat":false}
```

### Notes

- `seq` must be strictly increasing for deterministic downstream parsing
- `modifiers` should reflect active modifier state at the time of the event
- modifier keys themselves should also generate their own events
- repeated keydown events should be preserved with `isRepeat = true`

---

## Input scope

### Include

- all `keyDown`
- all `keyUp`
- modifier keys
- special keys
- repeated `keyDown`s
- current modifier state on every event

### Exclude

- mouse
- gestures
- trackpad
- app metadata / frontmost app context

---

## UI design

### Menu bar icon
Two-state icon:

- **empty circle** = logging disabled
- **filled circle** = logging enabled

For an active transcript write error, the app enters an explicit error state and should surface that clearly in the menu. The icon may optionally show a warning variant.

### Menu contents

- **Status: Enabled** / **Status: Disabled** / **Status: Error**
- **Enable Logging**
- **Disable Logging**
- **Open Settings…**
- **Reveal in Finder**
- **Clear Transcript**
- **Quit**

### Menu behavior details

- when enabled, **Enable Logging** can be disabled or hidden
- when disabled, **Disable Logging** can be disabled or hidden
- **Reveal in Finder** reveals transcript file or parent folder if file doesn’t exist yet
- **Clear Transcript** should require confirmation
- if transcript write fails, menu should show a clear error message

---

## Settings design

Single settings page containing:

- **Launch at login**
- **Permission status**
- **Reveal transcript in Finder**
- **Clear transcript**
- **Open System Settings** for permissions when needed

---

## Permissions UX

Because logging is global, the app must guide the user through required macOS permissions.

### Required UX pieces

The app should include:

- permission status detection
- a clear explanation of why permission is needed
- a button or action to open the relevant System Settings area
- state messaging when permission is missing

### First time user clicks Enable Logging

If permissions are missing:

1. app does **not** silently fail
2. app shows an explanation window or sheet:
   - TypingLens needs permission to monitor keyboard input globally.
   - Grant access in System Settings to enable logging.
3. app provides:
   - **Open System Settings**
   - **Cancel**
4. once permission is granted, enabling logging can begin immediately or after retry

### Settings permission section

Show one of:

- **Granted**
- **Not Granted**
- **Needs retry** if relevant

And include:

- **Open System Settings**

---

## Technical architecture

### 1. `AppState`
Responsible for:

- whether logging is enabled
- whether permissions are granted
- whether the app is in an error state
- current transcript path
- launch-at-login setting
- current error message, if any

This should be observable so UI updates instantly.

### 2. `KeyboardMonitor`
Responsible for:

- starting global keyboard capture
- stopping capture
- receiving `keyDown` and `keyUp`
- transforming native events into the app’s event model

This should emit normalized event objects, not write files directly.

### 3. `TranscriptWriter`
Responsible for:

- ensuring app support directory exists
- ensuring transcript file exists
- appending JSONL lines
- truncating file on clear
- recreating file if missing
- determining next sequence number on launch by reading the last line of the transcript

This should be the only component that touches the transcript file.

### 4. `PermissionManager`
Responsible for:

- checking current permission status
- triggering permission guidance flow
- opening System Settings when needed

### 5. `MenuBarController`
Responsible for:

- menu bar icon
- menu content
- enable/disable actions
- settings action
- reveal/clear actions
- surfacing active error state

### 6. `SettingsWindowController`
Responsible for:

- launch-at-login toggle
- permission status UI
- transcript actions
- permission guidance actions

---

## Data flow

### When app launches

1. app initializes state
2. app loads persisted settings:
   - enabled/disabled
   - launch at login
3. app checks permission status
4. `TranscriptWriter` determines the next `seq` by reading the last line of the transcript file
5. if previously enabled and permissions are granted:
   - keyboard monitor starts
6. menu bar icon updates to current state

### When keyboard event occurs

1. `KeyboardMonitor` receives native event
2. app normalizes it into event model
3. `TranscriptWriter` assigns/increments `seq`
4. event is serialized as one JSON line
5. line is appended to transcript
6. if append fails, app enters error state and logging stops

### When user clicks Enable Logging

1. check permissions
2. if not granted:
   - show guidance
   - offer **Open System Settings**
3. if granted:
   - clear any stale error state if appropriate
   - start monitor
   - update app state
   - persist enabled state
   - update menu icon

### When user clicks Disable Logging

1. stop monitor
2. persist disabled state
3. update menu icon

### When user clicks Clear Transcript

1. show confirmation
2. truncate transcript file to empty
3. if logging is active, continue appending new events normally

---

## Important implementation choices

### Sequence number persistence

- on launch, read the last line of `transcript.jsonl`
- parse its `seq`
- next event uses `lastSeq + 1`
- do not read the full file; use a tail-read strategy to find the last line efficiently

### Timestamp format

- use ISO 8601 UTC with fractional seconds
- example:

```json
"2026-04-14T12:01:03.510123Z"
```

### Modifier representation

Use a fixed list of normalized names, such as:

- `shift`
- `control`
- `option`
- `command`
- `capsLock`
- `function`

### File writing strategy

- append-only writes with newline termination for each event
- each record is one compact JSON object followed by `\n`

---

## Edge cases

### If permissions are revoked while app is running

- stop logging
- update state to blocked or disabled
- surface status in UI

### If transcript file is manually deleted while app is running

- next write recreates file automatically

### If transcript file cannot be written

- stop logging immediately
- enter explicit error state
- show visible error in the menu
- do not silently pretend logging is still working

### If launch-at-login is enabled but permissions are missing

- app launches
- remains disabled or blocked until permissions are fixed

---

## Known constraints

### macOS capture reliability

Global key capture is permission-sensitive and may behave differently under secure input contexts.

### Character reconstruction is not perfect

Even with:

- `keyCode`
- `characters`
- `charactersIgnoringModifiers`

some input methods and layouts may still be tricky.

### Long-term file growth

The transcript is intentionally a single forever-growing file. Any consumer of the log should parse incrementally rather than loading the entire file.

---

## v1 boundary

### Must-have

- menu bar app
- enable/disable logging
- global key capture
- keyDown/keyUp logging
- single JSONL transcript
- reveal in Finder
- clear transcript
- permission guidance
- settings window
- explicit error state for transcript write failures

### Not in v1

- privacy controls
- transcript search
- transcript viewer
- developer live log view
- app metadata/context
- log rotation
- session markers
- export/import
- analytics
