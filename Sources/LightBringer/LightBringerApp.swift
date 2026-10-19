import AppKit
import SwiftUI

@main
struct LightBringerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let clipboard = ClipboardStore()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let popover = NSPopover()
    private var rightClickMonitor: OptionRightClickMonitor?
    private let menuItemLimit = 5
    private let menuTitleLimit = 48

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        popover.behavior = .transient
        popover.contentSize = NSSize(width: 380, height: 520)
        popover.contentViewController = NSHostingController(
            rootView: ClipboardPanel(store: clipboard)
        )

        rightClickMonitor = OptionRightClickMonitor { [weak self] in
            self?.showContextMenuAtCursor()
        }
        rightClickMonitor?.start()

        guard let button = statusItem.button else { return }
        button.image = NSImage(
            systemSymbolName: "doc.on.clipboard",
            accessibilityDescription: "Light Bringer"
        )
        button.image?.isTemplate = true
        button.toolTip = "Light Bringer"
        button.target = self
        button.action = #selector(statusItemClicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    @objc private func statusItemClicked() {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    @objc private func openFromMenu() {
        showPopover()
    }

    @objc private func quitFromMenu() {
        NSApp.terminate(nil)
    }

    private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    @objc private func copyFromMenu(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? ClipboardItem else { return }
        clipboard.copy(item)
    }

    private func makeContextMenu() -> NSMenu {
        let menu = NSMenu()

        addSection(
            "Fixed",
            items: Array(clipboard.fixedItems.prefix(menuItemLimit)),
            to: menu
        )
        addSection(
            "Recent",
            items: Array(clipboard.recentItems.prefix(menuItemLimit)),
            to: menu
        )

        menu.addItem(
            withTitle: "Open Light Bringer",
            action: #selector(openFromMenu),
            keyEquivalent: ""
        )
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Quit Light Bringer",
            action: #selector(quitFromMenu),
            keyEquivalent: "q"
        )
        menu.items.forEach { if $0.target == nil { $0.target = self } }
        return menu
    }

    private func addSection(_ title: String, items: [ClipboardItem], to menu: NSMenu) {
        let header = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        if items.isEmpty {
            let empty = NSMenuItem(title: "None", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            empty.indentationLevel = 1
            menu.addItem(empty)
        }

        for item in items {
            let menuItem = NSMenuItem(
                title: menuTitle(for: item),
                action: #selector(copyFromMenu(_:)),
                keyEquivalent: ""
            )
            menuItem.target = self
            menuItem.representedObject = item
            menuItem.indentationLevel = 1
            if item.containsFiles {
                menuItem.image = NSImage(
                    systemSymbolName: "doc.fill",
                    accessibilityDescription: "File"
                )
            }
            menu.addItem(menuItem)
        }
        menu.addItem(.separator())
    }

    private func menuTitle(for item: ClipboardItem) -> String {
        let singleLine = item.text
            .split(whereSeparator: \.isNewline)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        guard singleLine.count > menuTitleLimit else { return singleLine }
        return singleLine.prefix(menuTitleLimit) + "…"
    }

    private func showContextMenuAtCursor() {
        NSApp.activate(ignoringOtherApps: true)
        makeContextMenu().popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    private func showContextMenu() {
        guard let button = statusItem.button else { return }
        makeContextMenu().popUp(
            positioning: nil,
            at: NSPoint(x: 0, y: button.bounds.height + 2),
            in: button
        )
    }
}
