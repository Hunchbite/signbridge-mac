import CryptoKit
import Foundation

/// Thin NDJSON client for `signbridge-rpc`.
///
/// Spawns one short-lived process per request so the menu bar app stays
/// crash-isolated from PKCS#11 modules.
actor SignBridgeClient {
    private let rpcURL: URL
    private let pin: String?

    init(rpcURL: URL, pin: String?) {
        self.rpcURL = rpcURL
        self.pin = pin
    }

    static func resolveRPCURL() -> URL? {
        let defaults = UserDefaults.standard.string(forKey: SettingsKeys.rpcPath)
        let candidates: [String] = [
            defaults,
            ProcessInfo.processInfo.environment["SIGNBRIDGE_RPC"],
            NSHomeDirectory() + "/.signbridge/bin/signbridge-rpc",
            "/Users/abhay/Desktop/Code/signbridge/target/release/signbridge-rpc",
            "/usr/local/bin/signbridge-rpc",
            "/opt/homebrew/bin/signbridge-rpc",
        ].compactMap { $0 }

        return candidates
            .map { URL(fileURLWithPath: $0) }
            .first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    func ping() async throws -> PingResult {
        try await request(method: "ping", extra: [:], as: PingResult.self)
    }

    func doctor() async throws -> DoctorResult {
        try await request(method: "doctor", extra: [:], as: DoctorResult.self)
    }

    func listCertificates() async throws -> [CertificateInfo] {
        let body = try await request(
            method: "listCertificates",
            extra: ["origin": "app://signbridge-mac"],
            as: ListCertificatesResult.self
        )
        return body.certificates
    }

    func signHash(
        certificateId: String,
        digest: Data,
        title: String?
    ) async throws -> SignResult {
        precondition(digest.count == 32, "SHA-256 digest required")
        var params: [String: Any] = [
            "certificateId": certificateId,
            "hashAlg": "SHA-256",
            "digestHex": digest.map { String(format: "%02x", $0) }.joined(),
        ]
        if let title {
            params["documentTitle"] = title
        }
        return try await request(
            method: "signHash",
            extra: [
                "origin": "app://signbridge-mac",
                "params": params,
            ],
            as: SignResult.self
        )
    }

    /// SHA-256 of file contents (digest-only — never sends the document).
    static func sha256File(at url: URL) throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while autoreleasepool(invoking: {
            let chunk = try? handle.read(upToCount: 1024 * 1024)
            guard let chunk, !chunk.isEmpty else { return false }
            hasher.update(data: chunk)
            return true
        }) {}
        return Data(hasher.finalize())
    }

    // MARK: - Wire

    private func request<T: Decodable>(
        method: String,
        extra: [String: Any],
        as _: T.Type
    ) async throws -> T {
        var payload: [String: Any] = [
            "id": UUID().uuidString,
            "method": method,
        ]
        for (k, v) in extra {
            payload[k] = v
        }
        let data = try JSONSerialization.data(withJSONObject: payload, options: [])
        let line = data + Data([0x0A])

        let process = Process()
        process.executableURL = rpcURL
        var args = ["--skip-origin"]
        if let pin, !pin.isEmpty {
            args += ["--pin", pin]
        }
        process.arguments = args

        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        stdin.fileHandleForWriting.write(line)
        try stdin.fileHandleForWriting.close()

        let outData = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let err = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw ClientError.rpcFailed(status: process.terminationStatus, stderr: err)
        }

        guard let firstLine = String(data: outData, encoding: .utf8)?
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init),
            let responseData = firstLine.data(using: .utf8)
        else {
            throw ClientError.badResponse
        }

        let decoded = try JSONDecoder.signBridge.decode(ProtocolResponse<T>.self, from: responseData)
        if decoded.ok, let result = decoded.result {
            return result
        }
        throw decoded.error ?? ClientError.unknown
    }
}

enum ClientError: LocalizedError {
    case rpcMissing
    case rpcFailed(status: Int32, stderr: String)
    case badResponse
    case unknown

    var errorDescription: String? {
        switch self {
        case .rpcMissing:
            return "signbridge-rpc not found. Build the engine or set its path in Settings."
        case .rpcFailed(let status, let stderr):
            return "Engine exited (\(status)): \(stderr.trimmingCharacters(in: .whitespacesAndNewlines))"
        case .badResponse:
            return "Could not parse engine response."
        case .unknown:
            return "Unknown signing error."
        }
    }
}

enum SettingsKeys {
    static let rpcPath = "rpcPath"
    static let pin = "tokenPin"
    static let selectedCertificateId = "selectedCertificateId"
}

extension JSONDecoder {
    static let signBridge: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        // Protocol uses camelCase already from serde rename_all = camelCase
        d.keyDecodingStrategy = .useDefaultKeys
        return d
    }()
}
