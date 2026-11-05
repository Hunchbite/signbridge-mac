import Foundation

struct ProtocolResponse<T: Decodable>: Decodable {
    let id: String
    let ok: Bool
    let result: T?
    let error: ProtocolError?
}

struct ProtocolError: Decodable, LocalizedError {
    let code: String
    let message: String

    var errorDescription: String? { message }
}

struct PingResult: Decodable {
    let name: String
    let version: String
}

struct CertificateInfo: Decodable, Identifiable, Hashable {
    let id: String
    let subject: String
    let issuer: String
    let serialHex: String
    let notBefore: String?
    let notAfter: String?
    let backend: String
    let tokenLabel: String?
    let keyAlgo: String?
    let certificateDerB64: String?

    var shortSubject: String {
        subject
            .split(separator: ",")
            .map(String.init)
            .first { $0.trimmingCharacters(in: .whitespaces).hasPrefix("CN=") }
            .map { $0.replacingOccurrences(of: "CN=", with: "").trimmingCharacters(in: .whitespaces) }
            ?? subject
    }

    var displayToken: String {
        tokenLabel?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Token"
    }
}

struct ListCertificatesResult: Decodable {
    let certificates: [CertificateInfo]
}

struct SignResult: Decodable {
    let signatureB64: String
    let certificateId: String
    let hashAlg: String
    let certificateDerB64: String?
}

struct DoctorModule: Decodable, Identifiable {
    var id: String { path }
    let name: String
    let region: String
    let path: String
    let notes: String
}

struct DoctorResult: Decodable {
    let os: String
    let modulesFound: [DoctorModule]
    let modulesMissingSample: [DoctorModule]
    let openscPresent: Bool
    let modulesConfigured: [String]
    let certificateCount: Int
    let hints: [String]
}

extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
