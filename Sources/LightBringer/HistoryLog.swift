import AppKit
import Foundation

/// Append-only plain-text log capped at `maximumLines`, oldest lines dropped first.
final class HistoryLog {
    let url: URL
    private let maximumLines: Int
    private var lineCount: Int

    static let directory: URL = {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        )[0]
        return base.appendingPathComponent("LightBringer", isDirectory: true)
    }()

    init(fileName: String, maximumLines: Int = 10_000) {
        url = Self.directory.appendingPathComponent(fileName)
        self.maximumLines = maximumLines
        try? FileManager.default.createDirectory(
            at: Self.directory, withIntermediateDirectories: true
        )
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        lineCount = Self.lines(in: url).count
    }

    func append(_ event: String, _ text: String) {
        let escaped = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\n", with: "\\n")
        let stamp = ISO8601DateFormatter().string(from: Date())
        let line = "\(stamp)\t\(event)\t\(escaped)\n"
        guard let data = line.data(using: .utf8),
              let handle = try? FileHandle(forWritingTo: url) else { return }
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: data)
        lineCount += 1

        if lineCount > maximumLines { trim() }
    }

    func open() {
        NSWorkspace.shared.open(url)
    }

    private func trim() {
        let kept = Self.lines(in: url).suffix(maximumLines)
        let text = kept.joined(separator: "\n") + "\n"
        try? text.write(to: url, atomically: true, encoding: .utf8)
        lineCount = kept.count
    }

    private static func lines(in url: URL) -> [String] {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return text.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
    }
}
