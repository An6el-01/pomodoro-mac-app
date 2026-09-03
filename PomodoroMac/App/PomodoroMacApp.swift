import AppKit
import SwiftUI
import UserNotifications

@MainActor
protocol MainWindowLifecycleWindow: AnyObject {
    var isMiniaturized: Bool { get }
    func orderOut()
    func deminiaturize()
    func makeKeyAndOrderFront()
}

extension NSWindow: MainWindowLifecycleWindow {
    func orderOut() { orderOut(nil) }
    func deminiaturize() { deminiaturize(nil) }
    func makeKeyAndOrderFront() { makeKeyAndOrderFront(nil) }
}

@MainActor
final class MainWindowLifecycleController: NSObject, NSWindowDelegate {
    static let shared = MainWindowLifecycleController {
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    private let activateApplication: () -> Void
    private var mainWindow: MainWindowLifecycleWindow?

    init(activateApplication: @escaping () -> Void) {
        self.activateApplication = activateApplication
    }

    func register(window: MainWindowLifecycleWindow) {
        mainWindow = window
        if let window = window as? NSWindow {
            window.level = .normal
            window.isReleasedWhenClosed = false
            window.delegate = self
        }
    }

    func shouldClose(window: MainWindowLifecycleWindow) -> Bool {
        window.orderOut()
        return false
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        shouldClose(window: sender)
    }

    func restoreMainWindow() {
        guard let mainWindow else { return }
        activateApplication()
        if mainWindow.isMiniaturized {
            mainWindow.deminiaturize()
        }
        mainWindow.makeKeyAndOrderFront()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        MainWindowLifecycleController.shared.restoreMainWindow()
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}

@main
struct PomodoroMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = PomodoroViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .frame(width: 340, height: 520)
                .background(MainWindowAccessor())
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}

private struct MainWindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                MainWindowLifecycleController.shared.register(window: window)
            }
        }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = view.window {
                MainWindowLifecycleController.shared.register(window: window)
            }
        }
    }
}
