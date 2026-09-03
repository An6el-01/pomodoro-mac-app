# Pomodoro for macOS

A compact native SwiftUI Pomodoro timer for macOS 13 and newer. It is a normal Dock app (never floating above other apps), and an active timer continues when its window is minimized, hidden, or closed.

## Features

- Focus timer: 25-minute default, editable duration, presets, required activity and domain
- Break timer: 5-minute default, editable duration, no metadata, never logged
- Start, pause, resume, and cancel; paused wall-clock time is excluded
- Completion restores the window, shows completion state, posts a notification, and plays a subtle system sound
- Last focus domain persists in `UserDefaults`
- Completed focus sessions append exactly one line to:
  `~/hermes-vault/00-Life/Activity/YYYY-MM-DD.jsonl`
- Domains: `university`, `career`, `salinas`, `hermes`, `admin`, `personal`

Each JSONL object contains `start`, `end`, `duration_minutes`, `domain`, `activity`, `context`, and `logged_at`. Dates are local timezone-aware ISO 8601 strings. Cancels and breaks are not logged, and write failures are displayed in the UI.

## Build and test

Open `PomodoroMac.xcodeproj` in Xcode 15 or newer, select the **PomodoroMac** scheme, and run. No third-party packages are used.

```sh
xcodebuild test -project PomodoroMac.xcodeproj -scheme PomodoroMac -destination 'platform=macOS'
```

The XCTest suite covers timer transitions, pause accounting, cancellation/no-log, break/no-log, exactly-once focus logging, JSON schema, timezone offsets, append preservation, and domain persistence.

Portable project checks (useful outside macOS):

```sh
python3 scripts/validate_project.py
```

## Verification status

Development occurred in WSL, where `swift` and `xcodebuild` are unavailable (`command not found`, exit 127). Native compilation and XCTest execution must therefore be run on macOS. The portable validator passes and checks project membership, the exact domain/schema contract, macOS 13 target, Dock mode, normal window level, and shared scheme XML.
