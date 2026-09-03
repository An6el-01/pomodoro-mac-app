#!/usr/bin/env python3
"""Portable checks for environments without macOS/Xcode."""
from pathlib import Path
import re
import sys
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
pbx = (root / "PomodoroMac.xcodeproj/project.pbxproj").read_text()
swift_files = sorted(root.glob("PomodoroMac/**/*.swift")) + sorted(root.glob("PomodoroMacTests/*.swift"))
errors: list[str] = []

for path in swift_files:
    occurrences = len(re.findall(rf"\b{re.escape(path.name)}\b", pbx))
    if occurrences < 2:
        errors.append(f"{path.relative_to(root)} is not fully referenced in project.pbxproj")

expected_domains = ["university", "career", "salinas", "hermes", "admin", "personal"]
domain_source = (root / "PomodoroMac/Core/ActivityLogEntry.swift").read_text()
domain_block = domain_source.split("enum FocusDomain", 1)[1].split("}", 1)[0]
found_domains = re.findall(r"^\s*case (\w+)\s*$", domain_block, re.MULTILINE)
if found_domains != expected_domains:
    errors.append(f"domain cases differ: {found_domains}")

required_schema = {"start", "end", "duration_minutes", "domain", "activity", "context", "logged_at"}
test_text = (root / "PomodoroMacTests/JSONLActivityLoggerTests.swift").read_text()
missing_schema = sorted(key for key in required_schema if f'"{key}"' not in test_text)
if missing_schema:
    errors.append(f"schema assertions missing: {missing_schema}")

if "MACOSX_DEPLOYMENT_TARGET = 13.0" not in pbx:
    errors.append("macOS 13 deployment target missing")
if "INFOPLIST_KEY_LSUIElement = NO" not in pbx:
    errors.append("normal Dock app setting missing")

app_source = (root / "PomodoroMac/App/PomodoroMacApp.swift").read_text()
completion_source = (root / "PomodoroMac/Services/CompletionPresenter.swift").read_text()
timer_source = (root / "PomodoroMac/Core/PomodoroTimer.swift").read_text()
controller_source = (root / "PomodoroMac/Core/PomodoroSessionController.swift").read_text()
timer_tests = (root / "PomodoroMacTests/PomodoroTimerTests.swift").read_text()
session_tests = (root / "PomodoroMacTests/SessionControllerTests.swift").read_text()

lifecycle_requirements = {
    "close interception": "func windowShouldClose(_ sender: NSWindow) -> Bool",
    "non-destructive close": "window.orderOut()",
    "retained closed window": "private var mainWindow: MainWindowLifecycleWindow?",
    "deminiaturize on restore": "mainWindow.deminiaturize()",
    "Dock reopen restoration": "MainWindowLifecycleController.shared.restoreMainWindow()",
}
for requirement, snippet in lifecycle_requirements.items():
    if snippet not in app_source:
        errors.append(f"main window lifecycle missing {requirement}")
if "MainWindowLifecycleController.shared.restoreMainWindow()" not in completion_source:
    errors.append("completion does not restore the retained main window")

if "return tick(at: date)" not in timer_source:
    errors.append("pause-at-expiry does not complete the timer")
if "return try handleCompletion(completedNow" not in controller_source:
    errors.append("pause-at-expiry completion is not logged")
if "testPauseAtOrAfterExpiryCompletesAndLogsInsteadOfPausing" not in session_tests:
    errors.append("pause-at-expiry regression test missing")
if "testResumeRejectsTimestampBeforeActualPause" not in timer_tests:
    errors.append("resume timestamp regression test missing")

try:
    ET.parse(root / "PomodoroMac.xcodeproj/xcshareddata/xcschemes/PomodoroMac.xcscheme")
except ET.ParseError as exc:
    errors.append(f"shared scheme XML invalid: {exc}")

if errors:
    print("PORTABLE VALIDATION FAILED")
    print("\n".join(f"- {error}" for error in errors))
    sys.exit(1)

print(f"PORTABLE VALIDATION PASSED: {len(swift_files)} Swift files referenced; domains, schema, deployment target, Dock mode, window lifecycle, pause-at-expiry safeguards, and scheme verified")
