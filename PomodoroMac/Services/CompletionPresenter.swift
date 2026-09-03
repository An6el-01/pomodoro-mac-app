import AppKit
import UserNotifications

enum CompletionPresenter {
    @MainActor
    static func present(mode: PomodoroViewModel.Mode) {
        MainWindowLifecycleController.shared.restoreMainWindow()

        NSSound(named: NSSound.Name("Glass"))?.play()

        let content = UNMutableNotificationContent()
        content.title = mode == .focus ? "Focus complete" : "Break complete"
        content.body = mode == .focus ? "Your focus session is finished." : "Your break is finished."
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
