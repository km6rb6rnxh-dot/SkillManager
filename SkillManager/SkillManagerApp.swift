import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct SkillManagerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var viewModel = SkillListViewModel()
    @AppStorage(Constants.UserDefaultsKeys.appearance) private var appearance: String = AppAppearance.system.rawValue

    private var colorScheme: ColorScheme? {
        AppAppearance(rawValue: appearance)?.colorScheme
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(viewModel)
                .preferredColorScheme(colorScheme)
        }
        .windowStyle(.automatic)
        .defaultSize(width: 920, height: 600)
        .windowResizability(.contentSize)

        Settings {
            SettingsView()
                .preferredColorScheme(colorScheme)
        }
    }
}
