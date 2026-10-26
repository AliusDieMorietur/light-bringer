import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ClipboardPanel: View {
    @ObservedObject var store: ClipboardStore
    @State private var newFixedText = ""
    @State private var copiedItemID: UUID?
    @State private var isShowingClearFixedConfirmation = false
    @State private var isShowingFilePicker = false
    @State private var isShowingPresetPicker = false
    @State private var presetAlertTitle = "Import Preset"
    @State private var presetMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    fixedSection
                    recentSection
                }
                .padding(12)
            }

            Divider()
            footer
        }
        .frame(width: 380, height: 520)
        .fileImporter(
            isPresented: $isShowingFilePicker,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true
        ) { result in
            guard case let .success(fileURLs) = result else { return }
            store.addFixedFiles(fileURLs)
        }
        .fileImporter(
            isPresented: $isShowingPresetPicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            guard case let .success(fileURLs) = result,
                  let fileURL = fileURLs.first else { return }
            do {
                let count = try store.importFixedItems(from: fileURL)
                presetAlertTitle = "Import Preset"
                presetMessage = count == 1
                    ? "Imported 1 fixed item."
                    : "Imported \(count) fixed items."
            } catch {
                presetAlertTitle = "Import Preset"
                presetMessage = "The file must contain a JSON array of strings."
            }
        }
        .alert(
            presetAlertTitle,
            isPresented: Binding(
                get: { presetMessage != nil },
                set: { if !$0 { presetMessage = nil } }
            )
        ) {
            Button("OK") { presetMessage = nil }
        } message: {
            Text(presetMessage ?? "")
        }
        .confirmationDialog(
            "Delete all fixed items?",
            isPresented: $isShowingClearFixedConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete All Fixed Items", role: .destructive) {
                store.clearFixedItems()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "doc.on.clipboard.fill")
                .foregroundStyle(.tint)
            Text("Light Bringer")
                .font(.headline)
            Spacer()
            Text("Clipboard")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
    }

    private var fixedSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Label("Fixed items", systemImage: "pin.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("History") { store.fixedLog.open() }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .help("Open the fixed items history file")
                if !store.fixedItems.isEmpty {
                    Button("Delete All") {
                        isShowingClearFixedConfirmation = true
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.red)
                }
            }

            if store.fixedItems.isEmpty {
                emptyMessage("Add text you use often.")
            } else {
                ForEach(store.fixedItems) { item in
                    itemButton(item, isFixed: true)
                }
            }

            HStack(spacing: 7) {
                TextField("Add a fixed text item", text: $newFixedText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addFixedItem)
                Button(action: addFixedItem) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.bordered)
                .disabled(newFixedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .help("Add fixed text")

                Button {
                    isShowingFilePicker = true
                } label: {
                    Image(systemName: "doc.badge.plus")
                }
                .buttonStyle(.bordered)
                .help("Add fixed files")

                Button {
                    isShowingPresetPicker = true
                } label: {
                    Image(systemName: "square.and.arrow.down")
                }
                .buttonStyle(.bordered)
                .help("Import fixed items preset from JSON")

                Button(action: exportPreset) {
                    Image(systemName: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
                .disabled(!store.fixedItems.contains { !$0.containsFiles })
                .help("Export fixed text items as JSON")
            }
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Label("Recent copies", systemImage: "clock.arrow.circlepath")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("History") { store.recentLog.open() }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .help("Open the recent copies history file")
                if !store.recentItems.isEmpty {
                    Button("Clear") { store.clearHistory() }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if store.recentItems.isEmpty {
                emptyMessage("Copied text and files will appear here.")
            } else {
                ForEach(store.recentItems) { item in
                    itemButton(item, isFixed: false)
                }
            }
        }
    }

    private func copyItem(_ item: ClipboardItem) {
        store.copy(item)
        copiedItemID = item.id
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            if copiedItemID == item.id { copiedItemID = nil }
        }
    }

    private func itemButton(_ item: ClipboardItem, isFixed: Bool) -> some View {
        let isCopied = copiedItemID == item.id
        let isPinned = !isFixed && store.isFixed(item)

        return HStack(spacing: 9) {
            Button { copyItem(item) } label: {
                HStack(spacing: 9) {
                    if item.containsFiles {
                        Image(systemName: item.fileURLs?.count == 1 ? "doc.fill" : "doc.on.doc.fill")
                            .frame(width: 18)
                            .foregroundStyle(.secondary)
                    }
                    Text(item.text)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 8)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Copy to clipboard")

            if !isFixed {
                Button { store.pin(item) } label: {
                    Image(systemName: isPinned ? "pin.fill" : "pin")
                        .frame(width: 18, height: 18)
                        .foregroundStyle(isPinned ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)
                .disabled(isPinned)
                .help(isPinned ? "Already in fixed items" : "Save to fixed items")
            }

            if isFixed {
                Button { store.removeFixedItem(id: item.id) } label: {
                    Image(systemName: "trash")
                        .frame(width: 18, height: 18)
                        .foregroundStyle(Color.secondary)
                }
                .buttonStyle(.plain)
                .help("Delete from fixed items")
            }

            Button { copyItem(item) } label: {
                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    .frame(width: 18, height: 18)
                    .foregroundStyle(isCopied ? Color.green : Color.secondary)
            }
            .buttonStyle(.plain)
            .help("Copy to clipboard")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 7))
        .contextMenu {
            if !isFixed {
                Button("Pin") { store.pin(item) }
            }
            Button("Delete", role: .destructive) {
                if isFixed {
                    store.removeFixedItem(id: item.id)
                } else {
                    store.removeRecentItem(id: item.id)
                }
            }
        }
    }

    private func emptyMessage(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
    }

    private static let appVersion =
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"

    private var footer: some View {
        HStack {
            Text("v\(Self.appVersion) · keeps the last 20 items")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.plain)
                .font(.caption)
        }
        .padding(12)
    }

    private func addFixedItem() {
        store.addFixedItem(newFixedText)
        newFixedText = ""
    }

    private func exportPreset() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "light-bringer-preset.json"
        panel.title = "Export Fixed Items Preset"

        guard panel.runModal() == .OK, let fileURL = panel.url else { return }
        do {
            let count = try store.exportFixedItems(to: fileURL)
            presetAlertTitle = "Export Preset"
            presetMessage = count == 1
                ? "Exported 1 fixed item."
                : "Exported \(count) fixed items."
        } catch {
            presetAlertTitle = "Export Preset"
            presetMessage = "The preset could not be saved."
        }
    }
}
