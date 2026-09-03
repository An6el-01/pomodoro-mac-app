# Pomodoro for macOS

A compact native SwiftUI Pomodoro timer for macOS 13 and newer. It is a normal Dock app (never floating above other apps), and an active timer continues when its window is minimized, hidden, or closed.

## Features

- Focus timer: 25-minute default, directly typed 1–180 minute duration, presets, required activity and domain
- Break timer: 5-minute default, directly typed 1–180 minute duration, no metadata, never logged
- Start, pause, resume, and cancel; paused wall-clock time is excluded
- Completion restores the window, posts a notification, plays a subtle system sound, and shows a prominent in-app alert for five seconds
- Accessible pastel styling adapts to macOS light and dark appearance
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

The XCTest suite covers timer transitions, pause accounting, cancellation/no-log, break/no-log, exactly-once focus logging, JSON schema, timezone offsets, append preservation, domain persistence, duration-input validation, and deterministic completion-alert dismissal.

Portable project checks (useful outside macOS):

```sh
python3 scripts/validate_project.py
```

## Verification status

Development occurred in WSL, where `swift` and `xcodebuild` are unavailable (`command not found`, exit 127). Native compilation and XCTest execution must therefore be run on macOS. The portable validator checks project membership, the exact domain/schema contract, macOS 13 target, Dock mode, normal window lifecycle, duration editing, adaptive UI and completion-alert safeguards, and shared scheme XML.
