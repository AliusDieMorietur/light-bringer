import AppKit
import Combine
import Foundation

struct ClipboardItem: Codable, Identifiable, Equatable {
    let id: UUID
    let text: String
    let createdAt: Date

    init(id: UUID = UUID(), text: String, createdAt: Date = Date()) {
        self.id = id
        self.text = text
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

        guard let text = pasteboard.string(forType: .string) else { return }
        addToHistory(text)
    }

    func copy(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        lastChangeCount = pasteboard.changeCount
        addToHistory(text)
    }

    func addFixedItem(_ text: String) {
        guard let validText = validated(text) else { return }
        guard !fixedItems.contains(where: { $0.text == validText }) else { return }
        fixedItems.append(ClipboardItem(text: validText))
        save(fixedItems, key: fixedItemsKey)
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
        addFixedItem(item.text)
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
        recentItems.removeAll { $0.text == validText }
        recentItems.insert(ClipboardItem(text: validText), at: 0)
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
