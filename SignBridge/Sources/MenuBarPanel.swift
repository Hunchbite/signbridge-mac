import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Primary menu-bar surface — one job: pick a cert and sign a fingerprint.
struct MenuBarPanel: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().opacity(0.35)
            content
            Divider().opacity(0.35)
            footer
        }
        .frame(width: 320)
        .background(.ultraThinMaterial)
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            let url: URL?
            if let data = item as? Data {
                url = URL(dataRepresentation: data, relativeTo: nil)
            } else if let str = item as? String {
                url = URL(fileURLWithPath: str)
            } else {
                url = item as? URL
            }
            guard let url else { return }
            Task { @MainActor in
                await model.sign(fileURL: url)
            }
        }
        return true
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("SignBridge")
                    .font(.system(size: 15, weight: .semibold, design: .default))
                Text(model.status.headline)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if model.isBusy {
                ProgressView()
                    .controlSize(.small)
            } else {
                Button {
                    Task { await model.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh certificates")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let banner = model.banner {
                Text(banner)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            switch model.status {
            case .missingEngine:
                EmptyHint(
                    symbol: "gearshape.2",
                    title: "Engine missing",
                    detail: "Build signbridge-rpc or set its path in Settings."
                )
            case .noCertificates, .ready, .readyWithCerts, .unknown:
                certificateSection
                signSection
            case .error(let message):
                EmptyHint(
                    symbol: "exclamationmark.triangle",
                    title: "Couldn’t reach the engine",
                    detail: message
                )
            }

            if let doctor = model.doctor {
                doctorStrip(doctor)
            }
        }
        .padding(14)
    }

    private var certificateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Certificate")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.4)

            if model.certificates.isEmpty {
                EmptyHint(
                    symbol: "cable.connector",
                    title: "No DSC found",
                    detail: "Insert your USB token. OpenSC is used for ePass2003 on Mac."
                )
            } else {
                VStack(spacing: 4) {
                    ForEach(model.certificates) { cert in
                        CertificateRow(
                            cert: cert,
                            selected: model.selectedCertificateId == cert.id
                        ) {
                            model.selectCertificate(cert.id)
                        }
                    }
                }
            }
        }
    }

    private var signSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                model.chooseAndSignFile()
            } label: {
                Label("Sign Document…", systemImage: "doc.badge.ellipsis")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(model.selectedCertificateId == nil || model.isBusy)
            .keyboardShortcut("o", modifiers: [.command])

            Text("Hashes locally. Only the fingerprint is signed on your token.")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)

            if model.lastSignatureB64 != nil {
                HStack(spacing: 8) {
                    Button("Copy Signature") { model.copySignature() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    Button("Save…") { model.saveSignature() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
        }
    }

    private func doctorStrip(_ doctor: DoctorResult) -> some View {
        HStack(spacing: 8) {
            Image(systemName: doctor.openscPresent ? "checkmark.seal.fill" : "seal")
                .foregroundStyle(doctor.openscPresent ? Color.accentColor : .secondary)
                .imageScale(.small)
            Text(doctor.openscPresent ? "OpenSC ready" : "OpenSC not detected")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(doctor.modulesFound.count) modules")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .padding(.top, 2)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button("Settings…") { openSettings() }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.system(size: 12))
            Spacer()
            Button("Quit") { model.quit() }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.system(size: 12))
                .keyboardShortcut("q", modifiers: [.command])
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

struct CertificateRow: View {
    let cert: CertificateInfo
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? Color.accentColor : .secondary)
                    .imageScale(.medium)
                    .padding(.top, 1)
                VStack(alignment: .leading, spacing: 2) {
                    Text(cert.shortSubject)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text("\(cert.displayToken) · \(cert.keyAlgo ?? "Key")")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(selected ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.04))
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct EmptyHint: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }
}
