import AppKit
import Combine
import Foundation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class AppModel: ObservableObject {
    enum EngineStatus: Equatable {
        case unknown
        case missingEngine
        case ready(version: String)
        case noCertificates
        case readyWithCerts(count: Int)
        case error(String)

        var symbolName: String {
            switch self {
            case .unknown: return "signature"
            case .missingEngine: return "exclamationmark.triangle"
            case .ready, .readyWithCerts: return "signature"
            case .noCertificates: return "signature"
            case .error: return "xmark.octagon"
            }
        }

        var accessibilityValue: String {
            switch self {
            case .unknown: return "Checking"
            case .missingEngine: return "Engine missing"
            case .ready(let v): return "Ready \(v)"
            case .noCertificates: return "No certificates"
            case .readyWithCerts(let n): return "\(n) certificates"
            case .error: return "Error"
            }
        }

        var headline: String {
            switch self {
            case .unknown: return "Starting…"
            case .missingEngine: return "Engine not found"
            case .ready(let v): return "Ready · \(v)"
            case .noCertificates: return "No certificates"
            case .readyWithCerts(let n): return n == 1 ? "1 certificate" : "\(n) certificates"
            case .error: return "Something went wrong"
            }
        }
    }

    @Published var status: EngineStatus = .unknown
    @Published var certificates: [CertificateInfo] = []
    @Published var selectedCertificateId: String?
    @Published var doctor: DoctorResult?
    @Published var lastSignatureB64: String?
    @Published var lastSignedFileName: String?
    @Published var isBusy = false
    @Published var banner: String?
    @Published var rpcPathDisplay: String = "—"

    @AppStorage(SettingsKeys.rpcPath) var storedRpcPath: String = ""
    @AppStorage(SettingsKeys.pin) var storedPin: String = ""
    @AppStorage(SettingsKeys.selectedCertificateId) private var storedCertId: String = ""

    init() {
        selectedCertificateId = storedCertId.nilIfEmpty
        Task { await refresh() }
    }

    func refresh() async {
        banner = nil
        guard let url = resolvedRPCURL() else {
            status = .missingEngine
            rpcPathDisplay = "Not found"
            certificates = []
            return
        }
        rpcPathDisplay = url.path
        isBusy = true
        defer { isBusy = false }

        let client = SignBridgeClient(rpcURL: url, pin: storedPin.nilIfEmpty)
        do {
            let ping = try await client.ping()
            let docs = try? await client.doctor()
            doctor = docs
            let certs = try await client.listCertificates()
            certificates = certs
            if let id = selectedCertificateId, certs.contains(where: { $0.id == id }) {
                // keep
            } else {
                selectedCertificateId = certs.first?.id
                storedCertId = selectedCertificateId ?? ""
            }
            if certs.isEmpty {
                status = .noCertificates
            } else {
                status = .readyWithCerts(count: certs.count)
            }
            if case .noCertificates = status, docs?.openscPresent == true {
                banner = "OpenSC is installed — plug in your DSC token."
            }
            _ = ping
        } catch {
            status = .error(error.localizedDescription)
            banner = error.localizedDescription
        }
    }

    func selectCertificate(_ id: String) {
        selectedCertificateId = id
        storedCertId = id
    }

    func chooseAndSignFile() {
        let panel = NSOpenPanel()
        panel.title = "Choose a document to sign"
        panel.message = "Only a SHA-256 fingerprint leaves this Mac. The file itself is never sent."
        panel.prompt = "Sign"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.pdf, .data, .item]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { await sign(fileURL: url) }
    }

    func sign(fileURL: URL) async {
        banner = nil
        lastSignatureB64 = nil
        guard let certId = selectedCertificateId else {
            banner = "Select a certificate first."
            return
        }
        guard let rpc = resolvedRPCURL() else {
            status = .missingEngine
            return
        }
        isBusy = true
        defer { isBusy = false }

        do {
            let digest = try SignBridgeClient.sha256File(at: fileURL)
            let client = SignBridgeClient(rpcURL: rpc, pin: storedPin.nilIfEmpty)
            let result = try await client.signHash(
                certificateId: certId,
                digest: digest,
                title: fileURL.lastPathComponent
            )
            lastSignatureB64 = result.signatureB64
            lastSignedFileName = fileURL.lastPathComponent
            banner = "Signed \(fileURL.lastPathComponent)"
            NSSound.beep()
        } catch {
            banner = error.localizedDescription
            status = .error(error.localizedDescription)
        }
    }

    func copySignature() {
        guard let sig = lastSignatureB64 else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(sig, forType: .string)
        banner = "Signature copied"
    }

    func saveSignature() {
        guard let sig = lastSignatureB64 else { return }
        let panel = NSSavePanel()
        panel.title = "Save signature"
        panel.nameFieldStringValue = (lastSignedFileName ?? "document") + ".sig.b64"
        panel.allowedContentTypes = [.plainText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? sig.write(to: url, atomically: true, encoding: .utf8)
        banner = "Saved signature"
    }

    func quit() {
        NSApp.terminate(nil)
    }

    private func resolvedRPCURL() -> URL? {
        if !storedRpcPath.isEmpty {
            let u = URL(fileURLWithPath: storedRpcPath)
            if FileManager.default.isExecutableFile(atPath: u.path) {
                return u
            }
        }
        return SignBridgeClient.resolveRPCURL()
    }
}
