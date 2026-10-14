import AppKit
import Combine
import Foundation

struct ClipboardItem: Codable, Identifiable, Equatable {
    let id: UUID
    let text: String
    let fileURLs: [URL]?
    let createdAt: Date

    var containsFiles: Bool { !(fileURLs?.isEmpty ?? true) }

    init(
        id: UUID = UUID(),
        text: String,
        fileURLs: [URL]? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.text = text
        self.fileURLs = fileURLs
        self.createdAt = createdAt
    }
}

@MainActor
final class ClipboardStore: ObservableObject {
    @Published private(set) var fixedItems: [ClipboardItem] = []
    @Published private(set) var recentItems: [ClipboardItem] = []

    private let pasteboard = NSPasteboard.general
    private let defaults = UserDefaults.standard
    private let fixedItemsKey = "fixedClipboardItems"
    private let recentItemsKey = "recentClipboardItems"
    private let maximumHistoryCount = 20
    private let maximumTextLength = 20_000

    private var lastChangeCount: Int
    private var timer: Timer?

    init() {
        lastChangeCount = pasteboard.changeCount
        fixedItems = Self.loadItems(key: fixedItemsKey)
        recentItems = Self.loadItems(key: recentItemsKey)

        if fixedItems.isEmpty && !defaults.bool(forKey: "hasCreatedInitialItems") {
            fixedItems = [
                ClipboardItem(text: "Thanks!"),
                ClipboardItem(text: "I'll get back to you shortly.")
            ]
            defaults.set(true, forKey: "hasCreatedInitialItems")
            save(fixedItems, key: fixedItemsKey)
        }

        checkClipboard()
        timer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkClipboard()
            }
        }
    }

    deinit {
        timer?.invalidate()
    }

    func checkClipboard() {
        let currentChangeCount = pasteboard.changeCount
        guard currentChangeCount != lastChangeCount else { return }
        lastChangeCount = currentChangeCount

        if let fileURLs = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL], !fileURLs.isEmpty {
            addFilesToHistory(fileURLs)
        } else if let text = pasteboard.string(forType: .string) {
            addToHistory(text)
        }
    }

    func copy(_ item: ClipboardItem) {
        pasteboard.clearContents()

        if let fileURLs = item.fileURLs, !fileURLs.isEmpty {
            pasteboard.writeObjects(fileURLs as [NSURL])
            lastChangeCount = pasteboard.changeCount
            addFilesToHistory(fileURLs)
        } else {
            pasteboard.setString(item.text, forType: .string)
            lastChangeCount = pasteboard.changeCount
            addToHistory(item.text)
        }
    }

    func addFixedItem(_ text: String) {
        guard let validText = validated(text) else { return }
        guard !fixedItems.contains(where: {
            !$0.containsFiles && $0.text == validText
        }) else { return }
        fixedItems.append(ClipboardItem(text: validText))
        save(fixedItems, key: fixedItemsKey)
    }

    func addFixedFiles(_ fileURLs: [URL]) {
        guard !fileURLs.isEmpty else { return }
        let standardizedURLs = fileURLs.map { $0.standardizedFileURL }
        guard !fixedItems.contains(where: {
            $0.fileURLs == standardizedURLs
        }) else { return }

        let title = standardizedURLs.map(\.lastPathComponent).joined(separator: ", ")
        fixedItems.append(
            ClipboardItem(text: title, fileURLs: standardizedURLs)
        )
        save(fixedItems, key: fixedItemsKey)
    }

    func importFixedItems(from fileURL: URL) throws -> Int {
        let hasAccess = fileURL.startAccessingSecurityScopedResource()
        defer {
            if hasAccess { fileURL.stopAccessingSecurityScopedResource() }
        }

        let data = try Data(contentsOf: fileURL)
        let texts = try JSONDecoder().decode([String].self, from: data)
        var importedCount = 0

        for text in texts {
            guard let validText = validated(text),
                  !fixedItems.contains(where: {
                      !$0.containsFiles && $0.text == validText
                  }) else { continue }
            fixedItems.append(ClipboardItem(text: validText))
            importedCount += 1
        }

        if importedCount > 0 {
            save(fixedItems, key: fixedItemsKey)
        }
        return importedCount
    }

    func exportFixedItems(to fileURL: URL) throws -> Int {
        let texts = fixedItems
            .filter { !$0.containsFiles }
            .map(\.text)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        let data = try encoder.encode(texts)
        try data.write(to: fileURL, options: .atomic)
        return texts.count
    }

    func removeFixedItem(id: UUID) {
        fixedItems.removeAll { $0.id == id }
        save(fixedItems, key: fixedItemsKey)
    }

    func clearFixedItems() {
        fixedItems.removeAll()
        save(fixedItems, key: fixedItemsKey)
    }

    func pin(_ item: ClipboardItem) {
        if let fileURLs = item.fileURLs, !fileURLs.isEmpty {
            addFixedFiles(fileURLs)
        } else {
            addFixedItem(item.text)
        }
    }

    func removeRecentItem(id: UUID) {
        recentItems.removeAll { $0.id == id }
        save(recentItems, key: recentItemsKey)
    }

    func clearHistory() {
        recentItems.removeAll()
        save(recentItems, key: recentItemsKey)
    }

    private func addToHistory(_ text: String) {
        guard let validText = validated(text) else { return }
        if let index = recentItems.firstIndex(where: {
            !$0.containsFiles && $0.text == validText
        }) {
            // Preserve the ID so the copied checkmark remains visible after
            // this item moves to the top of the recent list.
            let existingItem = recentItems.remove(at: index)
            recentItems.insert(existingItem, at: 0)
        } else {
            recentItems.insert(ClipboardItem(text: validText), at: 0)
        }
        trimAndSaveHistory()
    }

    private func addFilesToHistory(_ fileURLs: [URL]) {
        let standardizedURLs = fileURLs.map { $0.standardizedFileURL }
        if let index = recentItems.firstIndex(where: {
            $0.fileURLs == standardizedURLs
        }) {
            let existingItem = recentItems.remove(at: index)
            recentItems.insert(existingItem, at: 0)
        } else {
            let title = standardizedURLs.map(\.lastPathComponent).joined(separator: ", ")
            recentItems.insert(
                ClipboardItem(text: title, fileURLs: standardizedURLs),
                at: 0
            )
        }
        trimAndSaveHistory()
    }

    private func trimAndSaveHistory() {
        recentItems = Array(recentItems.prefix(maximumHistoryCount))
        save(recentItems, key: recentItemsKey)
    }

    private func validated(_ text: String) -> String? {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              text.count <= maximumTextLength else { return nil }
        return text
    }

    private func save(_ items: [ClipboardItem], key: String) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: key)
    }

    private static func loadItems(key: String) -> [ClipboardItem] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let items = try? JSONDecoder().decode([ClipboardItem].self, from: data) else {
            return []
        }
        return items
    }
}
