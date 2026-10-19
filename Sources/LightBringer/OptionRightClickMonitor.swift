import AppKit
import ApplicationServices

/// Watches for Option + right-click or Command + right-click anywhere on screen and swallows that click
/// so only Light Bringer's menu appears. Plain right-clicks pass through untouched.
/// Requires the Accessibility permission to create the event tap.
@MainActor
final class OptionRightClickMonitor {
    private let onTrigger: () -> Void
    private var tap: CFMachPort?
    private var retryTimer: Timer?

    init(onTrigger: @escaping () -> Void) {
        self.onTrigger = onTrigger
    }

    func start() {
        guard tap == nil else { return }

        if !AXIsProcessTrusted() {
            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
            scheduleRetry()
            return
        }

        let mask: CGEventMask =
            (1 << CGEventType.rightMouseDown.rawValue)
            | (1 << CGEventType.rightMouseUp.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<OptionRightClickMonitor>.fromOpaque(userInfo)
                .takeUnretainedValue()
            return MainActor.assumeIsolated { monitor.handle(type: type, event: event) }
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            scheduleRetry()
            return
        }

        self.tap = tap
        retryTimer?.invalidate()
        retryTimer = nil
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        case .rightMouseDown, .rightMouseUp:
            let flags = event.flags
            let hasOption = flags.contains(.maskAlternate)
            let hasCommand = flags.contains(.maskCommand)
            // Option or Command alone; combinations and Control pass through.
            let isTrigger = hasOption != hasCommand && !flags.contains(.maskControl)
            guard isTrigger else { return Unmanaged.passUnretained(event) }

            if type == .rightMouseDown {
                // Show the menu after the callback returns; popUp blocks while tracking.
                DispatchQueue.main.async { [onTrigger] in onTrigger() }
            }
            return nil
        default:
            return Unmanaged.passUnretained(event)
        }
    }

    /// Waits for the user to grant Accessibility access, then starts the tap.
    private func scheduleRetry() {
        guard retryTimer == nil else { return }
        retryTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if AXIsProcessTrusted() {
                    self.retryTimer?.invalidate()
                    self.retryTimer = nil
                    self.start()
                }
            }
        }
    }
}
