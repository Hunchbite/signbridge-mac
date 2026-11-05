import SwiftUI

@main
struct SignBridgeApp: App {
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarPanel()
                .environmentObject(appModel)
        } label: {
            MenuBarLabel(status: appModel.status)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(appModel)
        }
    }
}

/// Compact status glyph in the menu bar (Apple HIG: clear, monochrome-friendly).
struct MenuBarLabel: View {
    let status: AppModel.EngineStatus

    var body: some View {
        Image(systemName: status.symbolName)
            .symbolRenderingMode(.hierarchical)
            .accessibilityLabel("SignBridge")
            .accessibilityValue(status.accessibilityValue)
    }
}
