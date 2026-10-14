import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ClipboardPanel: View {
    @ObservedObject var store: ClipboardStore
    @State private var newFixedText = ""
    @State private var copiedItemID: UUID?
    @State private var isShowingClearFixedConfirmation = false
    @State private var isShowingFilePicker = false

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

    private func itemButton(_ item: ClipboardItem, isFixed: Bool) -> some View {
        Button {
            store.copy(item)
            copiedItemID = item.id
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1))
                if copiedItemID == item.id { copiedItemID = nil }
            }
        } label: {
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
                Image(systemName: copiedItemID == item.id ? "checkmark" : "doc.on.doc")
                    .frame(width: 18, height: 18)
                    .foregroundStyle(copiedItemID == item.id ? Color.green : Color.secondary)
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .help("Copy to clipboard")
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

    private var footer: some View {
        HStack {
            Text("Keeps the last 20 clipboard items")
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
}
