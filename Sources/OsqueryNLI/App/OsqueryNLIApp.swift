import SwiftUI
import AppKit

// Pure AppKit entry point for menu bar app
@main
@MainActor
enum AppMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate

        // Keep reference to prevent deallocation
        withExtendedLifetime(delegate) {
            app.run()
        }
    }
}

// MARK: - App Delegate

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSPopoverDelegate {
    var statusItem: NSStatusItem!
    var appState = AppState()

    private var queryWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var historyWindow: NSWindow?

    private var popover: NSPopover?
    private var eventMonitor: Any?

    // MARK: - NSWindowDelegate

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Hide window instead of closing to prevent app termination
        sender.orderOut(nil)
        return false
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }

        // Release window reference when closed to free memory
        if window === queryWindow {
            queryWindow = nil
        } else if window === settingsWindow {
            settingsWindow = nil
        } else if window === historyWindow {
            historyWindow = nil
        }
    }

    // MARK: - NSPopoverDelegate

    func popoverDidClose(_ notification: Notification) {
        stopEventMonitor()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon for menu bar only app
        NSApp.setActivationPolicy(.accessory)

        setupMenuBar()
        setupPopover()
        setupNotificationObservers()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep app running in menu bar even when all windows are closed
        return false
    }

    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenHistory),
            name: .openHistory,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenSettings),
            name: .openSettings,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenFullQueryWindow),
            name: .openFullQueryWindow,
            object: nil
        )
    }

    @objc private func handleOpenHistory() {
        openHistory()
    }

    @objc private func handleOpenSettings() {
        openSettings()
    }

    @objc private func handleOpenFullQueryWindow() {
        closePopover()
        openQuery()
    }

    private func setupPopover() {
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 380, height: 400)
        popover?.behavior = .transient
        popover?.animates = true
        popover?.delegate = self

        let popoverView = PopoverQueryView(
            onOpenFullWindow: { [weak self] in
                self?.closePopover()
                self?.openQuery()
            },
            onClose: { [weak self] in
                self?.closePopover()
            }
        )
        .environment(appState)

        popover?.contentViewController = NSHostingController(rootView: popoverView)
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "terminal.fill", accessibilityDescription: "Osquery NLI")
            button.action = #selector(handleStatusItemClick(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    @objc private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            // Right-click: show menu
            showMenu()
        } else {
            // Left-click: toggle popover
            togglePopover(sender)
        }
    }

    private func showMenu() {
        let menu = NSMenu()

        let queryItem = NSMenuItem(title: "New Query Window...", action: #selector(openQuery), keyEquivalent: "n")
        queryItem.target = self
        menu.addItem(queryItem)

        menu.addItem(NSMenuItem.separator())

        let historyItem = NSMenuItem(title: "History", action: #selector(openHistory), keyEquivalent: "h")
        historyItem.target = self
        menu.addItem(historyItem)

        menu.addItem(NSMenuItem.separator())

        // Provider info (disabled item)
        let providerItem = NSMenuItem(title: "Provider: \(appState.selectedProvider.displayName)", action: nil, keyEquivalent: "")
        providerItem.isEnabled = false
        menu.addItem(providerItem)

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit Osquery NLI", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil // Reset so left-click works again
    }

    private func togglePopover(_ sender: NSStatusBarButton) {
        if let popover = popover, popover.isShown {
            closePopover()
        } else {
            showPopover(sender)
        }
    }

    private func showPopover(_ sender: NSStatusBarButton) {
        guard let popover = popover else { return }

        // Reset state for fresh query
        appState.lastResult = nil
        appState.lastError = nil
        appState.currentQuery = ""

        popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)

        // Monitor for clicks outside the popover to close it
        startEventMonitor()
    }

    private func closePopover() {
        popover?.performClose(nil)
        stopEventMonitor()
    }

    private func startEventMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if self?.popover?.isShown == true {
                self?.closePopover()
            }
        }
    }

    private func stopEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    @objc func openQuery() {
        // Reset state for new query
        appState.lastResult = nil
        appState.lastError = nil
        appState.currentQuery = ""

        if queryWindow == nil {
            let contentView = QueryView()
                .environment(appState)

            queryWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            queryWindow?.title = "Osquery NLI"
            queryWindow?.contentView = NSHostingView(rootView: contentView)
            queryWindow?.center()
            queryWindow?.delegate = self
        }

        queryWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func openSettings() {
        if settingsWindow == nil {
            let contentView = SettingsView()
                .environment(appState)

            settingsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            settingsWindow?.title = "Settings"
            settingsWindow?.contentView = NSHostingView(rootView: contentView)
            settingsWindow?.center()
            settingsWindow?.delegate = self
        }

        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func openHistory() {
        if historyWindow == nil {
            let contentView = HistoryView()
                .environment(appState)

            historyWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 600),
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            historyWindow?.title = "History"
            historyWindow?.contentView = NSHostingView(rootView: contentView)
            historyWindow?.center()
            historyWindow?.delegate = self
        }

        historyWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
