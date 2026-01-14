import SwiftUI
import AppKit
import AppIntents

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
    private var shortcutsWindow: NSWindow?
    private var schemaBrowserWindow: NSWindow?
    private var scheduledQueriesWindow: NSWindow?
    private var scheduledResultsWindow: NSWindow?

    private var popover: NSPopover?
    private var eventMonitor: Any?

    // UserDefaults keys for window persistence
    private let queryWindowFrameKey = "queryWindowFrame"

    // MARK: - NSWindowDelegate

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Hide window instead of closing to prevent app termination
        sender.orderOut(nil)
        return false
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }

        // Save window frame before closing
        if window === queryWindow {
            saveWindowFrame(window, key: queryWindowFrameKey)
            queryWindow = nil
        } else if window === settingsWindow {
            settingsWindow = nil
        } else if window === historyWindow {
            historyWindow = nil
        } else if window === shortcutsWindow {
            shortcutsWindow = nil
        } else if window === schemaBrowserWindow {
            schemaBrowserWindow = nil
        } else if window === scheduledQueriesWindow {
            scheduledQueriesWindow = nil
        } else if window === scheduledResultsWindow {
            scheduledResultsWindow = nil
        }
    }

    func windowDidResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        if window === queryWindow {
            saveWindowFrame(window, key: queryWindowFrameKey)
        }
    }

    func windowDidMove(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        if window === queryWindow {
            saveWindowFrame(window, key: queryWindowFrameKey)
        }
    }

    private func saveWindowFrame(_ window: NSWindow, key: String) {
        let frame = window.frame
        let frameString = NSStringFromRect(frame)
        UserDefaults.standard.set(frameString, forKey: key)
    }

    private func restoreWindowFrame(_ window: NSWindow, key: String, defaultSize: NSSize) {
        if let frameString = UserDefaults.standard.string(forKey: key),
           !frameString.isEmpty {
            let frame = NSRectFromString(frameString)
            // Validate frame is on screen
            if frame.width > 100 && frame.height > 100 {
                window.setFrame(frame, display: true)
                return
            }
        }
        // Default: center with default size
        window.setContentSize(defaultSize)
        window.center()
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

        // Register App Shortcuts with the system
        OsqueryShortcuts.updateAppShortcutParameters()

        // Check for updates (respects 24-hour cooldown)
        UpdateChecker.shared.checkForUpdatesIfNeeded()
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
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleShowScheduledQueryResults(_:)),
            name: .showScheduledQueryResults,
            object: nil
        )
    }

    @objc private func handleShowScheduledQueryResults(_ notification: Foundation.Notification) {
        // Extract queryId from notification and open results directly
        if let userInfo = notification.userInfo,
           let queryId = userInfo["queryId"] as? UUID,
           let query = appState.scheduledQueries.first(where: { $0.id == queryId }) {
            openScheduledQueryResults(query)
        } else {
            // Fallback to scheduled queries list
            openScheduledQueries()
        }
    }

    func openScheduledQueryResults(_ query: ScheduledQuery) {
        // Always create a new window to show current results
        scheduledResultsWindow?.close()

        let contentView = ScheduledQueryResultsView(query: query)
            .environment(appState)
            .environment(\.fontScale, appState.fontScale)

        scheduledResultsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 550),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        scheduledResultsWindow?.title = "Results: \(query.name)"
        scheduledResultsWindow?.contentView = NSHostingView(rootView: contentView)
        scheduledResultsWindow?.center()
        scheduledResultsWindow?.delegate = self

        scheduledResultsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
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
        .environment(\.fontScale, appState.fontScale)

        popover?.contentViewController = NSHostingController(rootView: popoverView)
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            // Set initial icon directly (don't use updateMenuBarIcon which has guard for state changes)
            button.image = NSImage(systemSymbolName: "terminal.fill", accessibilityDescription: "Osquery NLI")
            button.toolTip = "Osquery NLI - Click to query"
            button.action = #selector(handleStatusItemClick(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Observe query state changes
        setupQueryStateObserver()
    }

    private var queryStateObserver: NSObjectProtocol?

    private func setupQueryStateObserver() {
        // Use a timer to poll the query state (simpler than manual observation)
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.updateMenuBarIcon(isQuerying: self.appState.isQuerying)
            }
        }
    }

    private var lastQueryingState = false

    private func updateMenuBarIcon(isQuerying: Bool) {
        guard let button = statusItem?.button else { return }

        // Only update if state changed
        guard isQuerying != lastQueryingState else { return }
        lastQueryingState = isQuerying

        if isQuerying {
            // Animated querying state
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
                .applying(.init(paletteColors: [.systemBlue]))
            button.image = NSImage(systemSymbolName: "terminal.fill", accessibilityDescription: "Osquery NLI - Querying")?
                .withSymbolConfiguration(config)
            button.toolTip = "Query in progress..."

            // Add a subtle animation effect by toggling appearance
            startMenuBarAnimation()
        } else {
            // Normal state
            stopMenuBarAnimation()
            button.image = NSImage(systemSymbolName: "terminal.fill", accessibilityDescription: "Osquery NLI")
            button.toolTip = "Osquery NLI - Click to query"
        }
    }

    private var menuBarAnimationTimer: Timer?

    private var animationToggle = false

    private func startMenuBarAnimation() {
        menuBarAnimationTimer?.invalidate()
        animationToggle = false
        menuBarAnimationTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let button = self.statusItem?.button else { return }
                self.animationToggle.toggle()
                let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
                    .applying(.init(paletteColors: [self.animationToggle ? .systemBlue : .systemCyan]))
                button.image = NSImage(systemSymbolName: "terminal.fill", accessibilityDescription: "Querying")?
                    .withSymbolConfiguration(config)
            }
        }
    }

    private func stopMenuBarAnimation() {
        menuBarAnimationTimer?.invalidate()
        menuBarAnimationTimer = nil
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

        // Favorites submenu
        let favoritesItem = NSMenuItem(title: "Favorites", action: nil, keyEquivalent: "")
        let favoritesSubmenu = NSMenu()
        if appState.favorites.isEmpty {
            let emptyItem = NSMenuItem(title: "No favorites yet", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            favoritesSubmenu.addItem(emptyItem)
        } else {
            for (index, favorite) in appState.favorites.prefix(10).enumerated() {
                let item = NSMenuItem(
                    title: favorite.displayName,
                    action: #selector(runFavoriteQuery(_:)),
                    keyEquivalent: index < 9 ? "\(index + 1)" : ""
                )
                item.target = self
                item.tag = index
                item.toolTip = favorite.query
                favoritesSubmenu.addItem(item)
            }
            if appState.favorites.count > 10 {
                favoritesSubmenu.addItem(NSMenuItem.separator())
                let moreItem = NSMenuItem(title: "View All Favorites...", action: #selector(openFavorites), keyEquivalent: "")
                moreItem.target = self
                favoritesSubmenu.addItem(moreItem)
            }
        }
        favoritesItem.submenu = favoritesSubmenu
        menu.addItem(favoritesItem)

        // Recent queries submenu
        let recentItem = NSMenuItem(title: "Recent Queries", action: nil, keyEquivalent: "")
        let recentSubmenu = NSMenu()
        let recentQueries = appState.queryHistory.prefix(8)
        if recentQueries.isEmpty {
            let emptyItem = NSMenuItem(title: "No recent queries", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            recentSubmenu.addItem(emptyItem)
        } else {
            for (index, entry) in recentQueries.enumerated() {
                let displayText = entry.query.count > 40
                    ? String(entry.query.prefix(40)) + "..."
                    : entry.query
                let item = NSMenuItem(
                    title: displayText,
                    action: #selector(runRecentQuery(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.tag = index
                item.toolTip = entry.query
                recentSubmenu.addItem(item)
            }
            recentSubmenu.addItem(NSMenuItem.separator())
            let historyItem = NSMenuItem(title: "View All History...", action: #selector(openHistory), keyEquivalent: "")
            historyItem.target = self
            recentSubmenu.addItem(historyItem)
        }
        recentItem.submenu = recentSubmenu
        menu.addItem(recentItem)

        menu.addItem(NSMenuItem.separator())

        let historyItem = NSMenuItem(title: "History", action: #selector(openHistory), keyEquivalent: "h")
        historyItem.target = self
        menu.addItem(historyItem)

        let schemaItem = NSMenuItem(title: "Schema Browser", action: #selector(openSchemaBrowser), keyEquivalent: "b")
        schemaItem.target = self
        menu.addItem(schemaItem)

        let scheduledItem = NSMenuItem(title: "Scheduled Queries", action: #selector(openScheduledQueries), keyEquivalent: "s")
        scheduledItem.keyEquivalentModifierMask = [.command, .shift]
        scheduledItem.target = self
        menu.addItem(scheduledItem)

        menu.addItem(NSMenuItem.separator())

        // Provider info (disabled item)
        let providerItem = NSMenuItem(title: "Provider: \(appState.selectedProvider.displayName)", action: nil, keyEquivalent: "")
        providerItem.isEnabled = false
        menu.addItem(providerItem)

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let shortcutsItem = NSMenuItem(title: "Keyboard Shortcuts", action: #selector(openKeyboardShortcuts), keyEquivalent: "/")
        shortcutsItem.keyEquivalentModifierMask = [.command, .shift]
        shortcutsItem.target = self
        menu.addItem(shortcutsItem)

        let updateItem = NSMenuItem(title: "Check for Updates...", action: #selector(checkForUpdates), keyEquivalent: "")
        updateItem.target = self
        menu.addItem(updateItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit Osquery NLI", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil // Reset so left-click works again
    }

    @objc private func runFavoriteQuery(_ sender: NSMenuItem) {
        let index = sender.tag
        guard index < appState.favorites.count else { return }
        let query = appState.favorites[index].query
        runQueryFromMenu(query)
    }

    @objc private func runRecentQuery(_ sender: NSMenuItem) {
        let index = sender.tag
        let recentQueries = Array(appState.queryHistory.prefix(8))
        guard index < recentQueries.count else { return }
        let query = recentQueries[index].query
        runQueryFromMenu(query)
    }

    private func runQueryFromMenu(_ query: String) {
        // Open the query window with the query pre-filled and execute it
        appState.currentQuery = query
        appState.lastResult = nil
        appState.lastError = nil
        openQuery()

        // Execute the query after a short delay to allow the window to appear
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            await appState.runQuery(query)
        }
    }

    @objc func openFavorites() {
        // For now, open the query window where favorites are accessible
        openQuery()
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
                .environment(\.fontScale, appState.fontScale)

            queryWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            queryWindow?.title = "Osquery NLI"
            queryWindow?.contentView = NSHostingView(rootView: contentView)
            queryWindow?.delegate = self

            // Restore saved window frame or use defaults
            restoreWindowFrame(queryWindow!, key: queryWindowFrameKey, defaultSize: NSSize(width: 600, height: 500))
        }

        queryWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func openSettings() {
        if settingsWindow == nil {
            let contentView = SettingsView()
                .environment(appState)
                .environment(\.fontScale, appState.fontScale)

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

    @objc func checkForUpdates() {
        UpdateChecker.shared.checkForUpdatesNow()
    }

    @objc func openHistory() {
        if historyWindow == nil {
            let contentView = HistoryView()
                .environment(appState)
                .environment(\.fontScale, appState.fontScale)

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

    @objc func openKeyboardShortcuts() {
        if shortcutsWindow == nil {
            let contentView = KeyboardShortcutsView()

            shortcutsWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 500),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            shortcutsWindow?.title = "Keyboard Shortcuts"
            shortcutsWindow?.contentView = NSHostingView(rootView: contentView)
            shortcutsWindow?.center()
            shortcutsWindow?.delegate = self
        }

        shortcutsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func openSchemaBrowser() {
        if schemaBrowserWindow == nil {
            let contentView = SchemaBrowserView()
                .environment(appState)
                .environment(\.fontScale, appState.fontScale)

            schemaBrowserWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            schemaBrowserWindow?.title = "Schema Browser"
            schemaBrowserWindow?.contentView = NSHostingView(rootView: contentView)
            schemaBrowserWindow?.center()
            schemaBrowserWindow?.delegate = self
        }

        schemaBrowserWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func openScheduledQueries() {
        if scheduledQueriesWindow == nil {
            let contentView = ScheduledQueriesView()
                .environment(appState)
                .environment(\.fontScale, appState.fontScale)

            scheduledQueriesWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
                styleMask: [.titled, .closable, .resizable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            scheduledQueriesWindow?.title = "Scheduled Queries"
            scheduledQueriesWindow?.contentView = NSHostingView(rootView: contentView)
            scheduledQueriesWindow?.center()
            scheduledQueriesWindow?.delegate = self
        }

        scheduledQueriesWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
