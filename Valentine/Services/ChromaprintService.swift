//
//  ChromaprintService.swift
//  Aries
//

import Foundation

struct ChromaprintFingerprint: Sendable {
    let fingerprint: String
    let duration: Int
}

enum ChromaprintService {
    private static let candidatePaths = [
        "/opt/homebrew/bin/fpcalc",
        "/usr/local/bin/fpcalc",
        "/usr/bin/fpcalc"
    ]

    static var isAvailable: Bool {
        locateFpcalc() != nil
    }

    static var fpcalcPath: String? {
        locateFpcalc()
    }

    static func fingerprint(for url: URL) async -> ChromaprintFingerprint? {
        guard let fpcalc = locateFpcalc() else { return nil }

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                continuation.resume(returning: runFpcalc(at: fpcalc, url: url))
            }
        }
    }

    private static func locateFpcalc() -> String? {
        for path in candidatePaths where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["fpcalc"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let path = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard let path, !path.isEmpty, FileManager.default.isExecutableFile(atPath: path) else { return nil }
            return path
        } catch {
            return nil
        }
    }

    private static func runFpcalc(at fpcalc: String, url: URL) -> ChromaprintFingerprint? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: fpcalc)
        process.arguments = ["-json", url.path]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return parseFingerprintJSON(data)
        } catch {
            return nil
        }
    }

    private static func parseFingerprintJSON(_ data: Data) -> ChromaprintFingerprint? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let fingerprint = json["fingerprint"] as? String,
              !fingerprint.isEmpty else { return nil }

        let duration: Int
        if let value = json["duration"] as? Int {
            duration = value
        } else if let value = json["duration"] as? Double {
            duration = Int(value.rounded())
        } else {
            return nil
        }

        return ChromaprintFingerprint(fingerprint: fingerprint, duration: duration)
    }
}
