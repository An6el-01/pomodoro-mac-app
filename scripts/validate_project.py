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
view_source = (root / "PomodoroMac/App/ContentView.swift").read_text()
view_model_source = (root / "PomodoroMac/App/PomodoroViewModel.swift").read_text()


def colors_in_block(marker: str) -> list[tuple[float, float, float]]:
    if marker not in view_source:
        errors.append(f"palette declaration missing: {marker}")
        return []
    block = view_source.split(marker, 1)[1].split("\n    }", 1)[0]
    return [
        tuple(map(float, match))
        for match in re.findall(
            r"Color\(red: ([0-9.]+), green: ([0-9.]+), blue: ([0-9.]+)\)",
            block,
        )
    ]


def palette_colors(property_name: str) -> list[tuple[float, float, float]]:
    return colors_in_block(f"var {property_name}")


def relative_luminance(color: tuple[float, float, float]) -> float:
    def linearize(component: float) -> float:
        return component / 12.92 if component <= 0.04045 else ((component + 0.055) / 1.055) ** 2.4

    red, green, blue = map(linearize, color)
    return 0.2126 * red + 0.7152 * green + 0.0722 * blue


def contrast_ratio(first: tuple[float, float, float], second: tuple[float, float, float]) -> float:
    lighter, darker = sorted((relative_luminance(first), relative_luminance(second)), reverse=True)
    return (lighter + 0.05) / (darker + 0.05)


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

ux_requirements = {
    "numeric minutes field": 'TextField("Minutes"',
    "numeric input submission": ".onSubmit { model.commitDurationInput() }",
    "numeric input focus-loss commit": "model.commitDurationInput()",
    "adaptive appearance": "@Environment(\\.colorScheme)",
    "opaque editor card": "PomodoroPalette.card",
    "completion overlay": "CompletionAlertOverlay",
}
for requirement, snippet in ux_requirements.items():
    if snippet not in view_source:
        errors.append(f"Pomodoro UX missing {requirement}")
if "Stepper(" in view_source:
    errors.append("minutes editor still uses Stepper")

contrast_results: dict[str, float] = {}
light_gradient = colors_in_block("var backgroundGradient")[-2:]
light_card_colors = colors_in_block("static func card")
light_field_colors = palette_colors("field")
light_accent_colors = palette_colors("accent")
button_text_colors = palette_colors("buttonText")
light_error_colors = palette_colors("error")
if (
    len(light_gradient) == 2
    and len(light_card_colors) >= 2
    and len(light_field_colors) >= 2
    and len(light_accent_colors) >= 2
    and button_text_colors
    and len(light_error_colors) >= 2
):
    light_card = light_card_colors[-1]
    light_field = light_field_colors[-1]
    light_accent = light_accent_colors[-1]
    button_text = button_text_colors[-1]
    light_error = light_error_colors[-1]
    contrast_results = {
        "focus/field": contrast_ratio(light_accent, light_field),
        "focus/card": contrast_ratio(light_accent, light_card),
        "selected-button text": contrast_ratio(button_text, light_accent),
        "error/pink gradient": contrast_ratio(light_error, light_gradient[0]),
        "error/blue gradient": contrast_ratio(light_error, light_gradient[1]),
    }
    for pairing in ("focus/field", "focus/card"):
        if contrast_results[pairing] < 3.0:
            errors.append(f"light {pairing} contrast is {contrast_results[pairing]:.2f}:1; requires 3.00:1")
    for pairing in ("selected-button text", "error/pink gradient", "error/blue gradient"):
        if contrast_results[pairing] < 4.5:
            errors.append(f"light {pairing} contrast is {contrast_results[pairing]:.2f}:1; requires 4.50:1")

behavior_requirements = {
    "digit sanitization": "struct DurationInput",
    "duration clamp": "min(180, max(1, value))",
    "five-second alert": "schedule(after: 5",
    "stale alert guard": "guard self?.generation == generation",
}
for requirement, snippet in behavior_requirements.items():
    if snippet not in view_model_source:
        errors.append(f"Pomodoro behavior missing {requirement}")
for test_name in [
    "testEditingAcceptsDigitsAndAllowsTemporaryEmptyText",
    "testCommitClampsMinutesToSupportedRange",
    "testAlertDismissesAfterExactlyFiveSeconds",
    "testOldDismissalCannotHideNewerAlert",
]:
    if test_name not in session_tests:
        errors.append(f"UX regression test missing: {test_name}")

try:
    ET.parse(root / "PomodoroMac.xcodeproj/xcshareddata/xcschemes/PomodoroMac.xcscheme")
except ET.ParseError as exc:
    errors.append(f"shared scheme XML invalid: {exc}")

if errors:
    print("PORTABLE VALIDATION FAILED")
    print("\n".join(f"- {error}" for error in errors))
    sys.exit(1)

contrast_summary = ", ".join(f"{pairing} {ratio:.2f}:1" for pairing, ratio in contrast_results.items())
print(f"PORTABLE VALIDATION PASSED: {len(swift_files)} Swift files referenced; domains, schema, deployment target, Dock mode, window lifecycle, timer safeguards, accessible adaptive UI, numeric duration input, five-second alert behavior, and scheme verified")
print(f"Light-mode contrast: {contrast_summary}")
