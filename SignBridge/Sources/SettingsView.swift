import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage(SettingsKeys.rpcPath) private var rpcPath: String = ""
    @AppStorage(SettingsKeys.pin) private var pin: String = ""

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }
            aboutTab
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 440, height: 280)
    }

    private var generalTab: some View {
        Form {
            Section {
                TextField("Engine path", text: $rpcPath, prompt: Text("Automatic"))
                SecureField("Token PIN", text: $pin, prompt: Text("Optional — leave empty to prompt later"))
            } header: {
                Text("Signing engine")
            } footer: {
                Text("Defaults to ~/.signbridge/bin/signbridge-rpc or a local release build. PIN is stored in UserDefaults for convenience — prefer Keychain for production builds.")
            }

            Section("Status") {
                LabeledContent("Resolved") {
                    Text(model.rpcPathDisplay)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .foregroundStyle(.secondary)
                }
                Button("Refresh") {
                    Task { await model.refresh() }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var aboutTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                Image(systemName: "signature")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(.secondary)
                    .frame(width: 56, height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.primary.opacity(0.06))
                    )
                VStack(alignment: .leading, spacing: 4) {
                    Text("SignBridge")
                        .font(.title2.weight(.semibold))
                    Text("Digest signing for Indian DSC and PKCS#11 tokens.")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
            }

            Text("Private keys never leave your token. Documents are hashed on this Mac; only the fingerprint is signed.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Link("Framework on GitHub", destination: URL(string: "https://github.com/Hunchbite/signbridge")!)
                .font(.callout)

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
