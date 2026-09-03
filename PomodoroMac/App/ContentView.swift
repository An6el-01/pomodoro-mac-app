import SwiftUI

struct ContentView: View {
    @ObservedObject var model: PomodoroViewModel
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var durationIsFocused: Bool

    private var palette: PomodoroPalette { PomodoroPalette(colorScheme: colorScheme) }

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(colors: palette.backgroundGradient,
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("Pomodoro")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(palette.textPrimary)

                Picker("Session", selection: modeBinding) {
                    ForEach(PomodoroViewModel.Mode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .disabled(!model.canEdit)

                Text(model.clockText)
                    .font(.system(size: 58, weight: .medium, design: .rounded).monospacedDigit())
                    .foregroundStyle(palette.textPrimary)
                    .accessibilityLabel("Time remaining")
                    .accessibilityValue(model.clockText)

                if model.canEdit {
                    editor
                } else {
                    runningSummary
                }

                controls

                if let error = model.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(palette.error)
                        .multilineTextAlignment(.center)
                        .accessibilityLabel("Error: \(error)")
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            CompletionAlertOverlay(state: model.completionAlert, palette: palette)
                .padding(.top, 12)
                .padding(.horizontal, 20)
        }
    }

    @ViewBuilder
    private var editor: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Minutes")
                    .foregroundStyle(palette.textPrimary)
                Spacer()
                TextField("Minutes", text: durationInputBinding)
                    .textFieldStyle(.plain)
                    .font(.body.monospacedDigit())
                    .foregroundStyle(palette.textPrimary)
                    .multilineTextAlignment(.trailing)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frame(width: 70)
                    .background(palette.field, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(durationIsFocused ? palette.accent : palette.border, lineWidth: durationIsFocused ? 2 : 1)
                    }
                    .focused($durationIsFocused)
                    .onSubmit { model.commitDurationInput() }
                    .onChange(of: durationIsFocused) { isFocused in
                        if !isFocused { model.commitDurationInput() }
                    }
                    .accessibilityLabel("Duration in minutes")
            }

            HStack(spacing: 8) {
                ForEach(model.mode == .focus ? [15, 30, 45, 60] : [5, 10, 15], id: \.self) { minutes in
                    Button("\(minutes)m") {
                        if model.mode == .focus { model.selectFocusPreset(minutes) }
                        else { model.selectBreakPreset(minutes) }
                    }
                    .buttonStyle(PastelButtonStyle(tinted: model.durationMinutes == minutes, palette: palette))
                }
            }

            if model.mode == .focus {
                styledTextField("Activity (required)", text: $model.activity)
                HStack {
                    Text("Domain")
                        .foregroundStyle(palette.textPrimary)
                    Spacer()
                    Picker("Domain", selection: $model.selectedDomain) {
                        Text("Choose domain…").tag(FocusDomain?.none)
                        ForEach(FocusDomain.allCases) { domain in
                            Text(domain.rawValue).tag(Optional(domain))
                        }
                    }
                    .labelsHidden()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity)
                .background(palette.field, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                styledTextField("Context (optional)", text: $model.context)
            } else {
                Text("Breaks are not added to the activity log.")
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background(PomodoroPalette.card(colorScheme),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(palette.border, lineWidth: 1)
        }
    }

    private func styledTextField(_ title: String, text: Binding<String>) -> some View {
        TextField(title, text: text)
            .textFieldStyle(.plain)
            .foregroundStyle(palette.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(palette.field, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(palette.border, lineWidth: 1)
            }
    }

    private var runningSummary: some View {
        VStack(spacing: 5) {
            Text(model.state == .completed ? "Complete" : (model.mode == .focus ? model.activity : "Break"))
                .font(.headline)
                .foregroundStyle(palette.textPrimary)
            if model.mode == .focus, let domain = model.selectedDomain {
                Text(domain.rawValue)
                    .font(.caption)
                    .foregroundStyle(palette.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(PomodoroPalette.card(colorScheme),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(palette.border, lineWidth: 1)
        }
    }

    @ViewBuilder
    private var controls: some View {
        switch model.state {
        case .idle:
            Button("Start") { model.start() }
                .buttonStyle(PastelButtonStyle(tinted: true, palette: palette))
                .disabled(model.mode == .focus && (model.activity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.selectedDomain == nil))
        case .running:
            HStack {
                Button("Pause") { model.pause() }
                    .buttonStyle(PastelButtonStyle(tinted: true, palette: palette))
                Button("Cancel", role: .destructive) { model.cancel() }
                    .foregroundStyle(palette.error)
            }
        case .paused:
            HStack {
                Button("Resume") { model.resume() }
                    .buttonStyle(PastelButtonStyle(tinted: true, palette: palette))
                Button("Cancel", role: .destructive) { model.cancel() }
                    .foregroundStyle(palette.error)
            }
        case .completed:
            Button("New Session") { model.cancel() }
                .buttonStyle(PastelButtonStyle(tinted: true, palette: palette))
        }
    }

    private var durationInputBinding: Binding<String> {
        Binding(get: { model.durationInput }, set: { model.updateDurationInput($0) })
    }

    private var modeBinding: Binding<PomodoroViewModel.Mode> {
        Binding(get: { model.mode }, set: { mode in
            model.commitDurationInput()
            model.mode = mode
            model.durationChanged()
        })
    }
}

private struct CompletionAlertOverlay: View {
    @ObservedObject var state: CompletionAlertState
    let palette: PomodoroPalette

    var body: some View {
        if let message = state.message {
            Label(message, systemImage: "checkmark.circle.fill")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(palette.alertText)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(palette.alertBackground,
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .black.opacity(0.22), radius: 12, y: 5)
                .transition(.move(edge: .top).combined(with: .opacity))
                .accessibilityAddTraits(.isStaticText)
        }
    }
}

private struct PastelButtonStyle: ButtonStyle {
    let tinted: Bool
    let palette: PomodoroPalette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .fontWeight(tinted ? .semibold : .regular)
            .foregroundStyle(tinted ? palette.buttonText : palette.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(tinted ? palette.accent : palette.field,
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(tinted ? palette.accentBorder : palette.border, lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

private struct PomodoroPalette {
    let colorScheme: ColorScheme

    var backgroundGradient: [Color] {
        colorScheme == .dark
            ? [Color(red: 0.20, green: 0.14, blue: 0.23), Color(red: 0.10, green: 0.22, blue: 0.30)]
            : [Color(red: 0.91, green: 0.67, blue: 0.75), Color(red: 0.62, green: 0.78, blue: 0.90)]
    }

    static func card(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(red: 0.13, green: 0.17, blue: 0.22)
            : Color(red: 0.98, green: 0.96, blue: 0.97)
    }

    var field: Color {
        colorScheme == .dark
            ? Color(red: 0.19, green: 0.24, blue: 0.30)
            : Color(red: 1.00, green: 0.99, blue: 1.00)
    }

    var textPrimary: Color {
        colorScheme == .dark
            ? Color(red: 0.94, green: 0.95, blue: 0.97)
            : Color(red: 0.08, green: 0.13, blue: 0.21)
    }

    var textSecondary: Color {
        colorScheme == .dark
            ? Color(red: 0.74, green: 0.79, blue: 0.84)
            : Color(red: 0.24, green: 0.30, blue: 0.38)
    }

    var accent: Color {
        colorScheme == .dark
            ? Color(red: 0.45, green: 0.68, blue: 0.83)
            : Color(red: 0.34, green: 0.57, blue: 0.76)
    }

    var accentBorder: Color {
        colorScheme == .dark
            ? Color(red: 0.62, green: 0.80, blue: 0.91)
            : Color(red: 0.22, green: 0.43, blue: 0.60)
    }

    var buttonText: Color {
        Color(red: 0.05, green: 0.10, blue: 0.16)
    }

    var border: Color {
        colorScheme == .dark ? Color.white.opacity(0.20) : Color.black.opacity(0.18)
    }

    var error: Color {
        colorScheme == .dark
            ? Color(red: 1.00, green: 0.54, blue: 0.56)
            : Color(red: 0.56, green: 0.03, blue: 0.08)
    }

    var alertBackground: Color {
        colorScheme == .dark
            ? Color(red: 0.48, green: 0.76, blue: 0.63)
            : Color(red: 0.75, green: 0.91, blue: 0.80)
    }

    var alertText: Color { Color(red: 0.04, green: 0.16, blue: 0.11) }
}
