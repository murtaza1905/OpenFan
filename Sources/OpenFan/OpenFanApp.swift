import SwiftUI
import AppKit

@main
struct OpenFanApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var controller = FanController.shared
    @ObservedObject private var helper = HelperManager.shared

    var body: some Scene {
        WindowGroup("OpenFan", id: WindowID.main) {
            MainWindow()
                .environmentObject(controller)
                .environmentObject(helper)
                .frame(minWidth: 640, minHeight: 460)
        }
        .defaultSize(width: 720, height: 520)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        MenuBarExtra {
            MenuBarView()
                .environmentObject(controller)
                .environmentObject(helper)
        } label: {
            Text(controller.menuBarTitle)
                .monospacedDigit()
        }
        .menuBarExtraStyle(.window)
    }
}

enum WindowID {
    static let main = "main"
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        FanController.shared.start()
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if FanController.shared.settings.resetToAutoOnQuit {
            FanController.shared.resetAllToAutoBlocking()
        }
        return .terminateNow
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
