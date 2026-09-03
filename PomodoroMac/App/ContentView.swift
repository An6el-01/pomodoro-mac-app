import SwiftUI

struct ContentView: View {
    @ObservedObject var model: PomodoroViewModel

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.97, green: 0.91, blue: 0.94),
                                    Color(red: 0.89, green: 0.94, blue: 0.98)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("Pomodoro")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))

                Picker("Session", selection: $model.mode) {
                    ForEach(PomodoroViewModel.Mode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .disabled(!model.canEdit)
                .onChange(of: model.mode) { _ in model.durationChanged() }

                Text(model.clockText)
                    .font(.system(size: 58, weight: .medium, design: .rounded).monospacedDigit())
                    .foregroundStyle(Color.primary.opacity(0.82))
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
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .accessibilityLabel("Error: \(error)")
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    @ViewBuilder
    private var editor: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Minutes")
                Spacer()
                Stepper(value: durationBinding, in: 1...180) {
                    Text("\(model.durationMinutes)")
                        .monospacedDigit()
                        .frame(minWidth: 28, alignment: .trailing)
                }
            }

            HStack(spacing: 8) {
                ForEach(model.mode == .focus ? [15, 25, 45, 60] : [5, 10, 15], id: \.self) { minutes in
                    Button("\(minutes)m") {
                        if model.mode == .focus { model.selectFocusPreset(minutes) }
                        else { model.selectBreakPreset(minutes) }
                        model.durationChanged()
                    }
                    .buttonStyle(PastelButtonStyle(tinted: model.durationMinutes == minutes))
                }
            }

            if model.mode == .focus {
                TextField("Activity (required)", text: $model.activity)
                    .textFieldStyle(.roundedBorder)
                Picker("Domain", selection: $model.selectedDomain) {
                    Text("Choose domain…").tag(FocusDomain?.none)
                    ForEach(FocusDomain.allCases) { domain in
                        Text(domain.rawValue).tag(Optional(domain))
                    }
                }
                TextField("Context (optional)", text: $model.context)
                    .textFieldStyle(.roundedBorder)
            } else {
                Text("Breaks are not added to the activity log.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background(.white.opacity(0.48), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var runningSummary: some View {
        VStack(spacing: 5) {
            Text(model.state == .completed ? "Complete" : (model.mode == .focus ? model.activity : "Break"))
                .font(.headline)
            if model.mode == .focus, let domain = model.selectedDomain {
                Text(domain.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(.white.opacity(0.48), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private var controls: some View {
        switch model.state {
        case .idle:
            Button("Start") { model.start() }
                .buttonStyle(PastelButtonStyle(tinted: true))
                .disabled(model.mode == .focus && (model.activity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.selectedDomain == nil))
        case .running:
            HStack {
                Button("Pause") { model.pause() }
                Button("Cancel", role: .destructive) { model.cancel() }
            }
        case .paused:
            HStack {
                Button("Resume") { model.resume() }
                    .buttonStyle(PastelButtonStyle(tinted: true))
                Button("Cancel", role: .destructive) { model.cancel() }
            }
        case .completed:
            Button("New Session") { model.cancel() }
                .buttonStyle(PastelButtonStyle(tinted: true))
        }
    }

    private var durationBinding: Binding<Int> {
        Binding(get: { model.durationMinutes }, set: { value in
            if model.mode == .focus { model.focusMinutes = value }
            else { model.breakMinutes = value }
            model.durationChanged()
        })
    }
}

private struct PastelButtonStyle: ButtonStyle {
    let tinted: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(tinted ? Color(red: 0.70, green: 0.82, blue: 0.95) : Color.white.opacity(0.55),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
