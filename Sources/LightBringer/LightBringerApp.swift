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
    private lazy var contextMenu: NSMenu = {
        let menu = NSMenu()
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
        menu.items.forEach { $0.target = self }
        return menu
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        popover.behavior = .transient
        popover.contentSize = NSSize(width: 380, height: 520)
        popover.contentViewController = NSHostingController(
            rootView: ClipboardPanel(store: clipboard)
        )

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

    private func showContextMenu() {
        guard let button = statusItem.button else { return }
        contextMenu.popUp(
            positioning: nil,
            at: NSPoint(x: 0, y: button.bounds.height + 2),
            in: button
        )
    }
}
