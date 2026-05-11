import SwiftUI
import AppKit
import Combine
import ServiceManagement

class FileStore: ObservableObject {
    @Published var droppedFileURLs: [URL] = [] {
        didSet { saveBookmarks() }
    }
    
    @Published var pinnedPaths: Set<String> = [] {
        didSet {
            UserDefaults.standard.set(Array(pinnedPaths), forKey: "pinned_paths")
            saveBookmarks()
        }
    }
    
    @Published var launchAtLogin: Bool = false {
        didSet { toggleAutostart() }
    }
    
    @Published var appLanguage: String = "system" {
        didSet { UserDefaults.standard.set(appLanguage, forKey: "app_language") }
    }
    
    private let bookmarksKey = "saved_file_bookmarks"
    private let autostartKey = "launch_at_login"
    
    init() {
        self.launchAtLogin = UserDefaults.standard.bool(forKey: autostartKey)
        self.appLanguage = UserDefaults.standard.string(forKey: "app_language") ?? "system"
        let savedPins = UserDefaults.standard.stringArray(forKey: "pinned_paths") ?? []
        self.pinnedPaths = Set(savedPins)
        loadBookmarks()
    }
    
    func remove(url: URL) {
        withAnimation(.spring()) {
            pinnedPaths.remove(url.path)
            droppedFileURLs.removeAll { $0 == url }
        }
    }
    
    func clearAll() {
        withAnimation(.spring()) {
            droppedFileURLs.removeAll { !pinnedPaths.contains($0.path) }
        }
    }
    
    func togglePin(for url: URL) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            if pinnedPaths.contains(url.path) {
                pinnedPaths.remove(url.path)
            } else {
                pinnedPaths.insert(url.path)
            }
        }
    }
    
    func isPinned(_ url: URL) -> Bool {
        pinnedPaths.contains(url.path)
    }

    private func toggleAutostart() {
        UserDefaults.standard.set(launchAtLogin, forKey: autostartKey)
        let service = SMAppService.mainApp
        do {
            if launchAtLogin { if service.status != .enabled { try service.register() } }
            else { if service.status == .enabled { try service.unregister() } }
        } catch { print("Autostart Fehler: \(error)") }
    }
    
    private func saveBookmarks() {
        let bookmarks = droppedFileURLs.compactMap { url -> Data? in
            return try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        }
        UserDefaults.standard.set(bookmarks, forKey: bookmarksKey)
    }
    
    private func loadBookmarks() {
        guard let dataArray = UserDefaults.standard.array(forKey: bookmarksKey) as? [Data] else { return }
        self.droppedFileURLs = dataArray.compactMap { data in
            var isStale = false
            guard let url = try? URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale) else { return nil }
            _ = url.startAccessingSecurityScopedResource()
            return url
        }
    }
}

class DragObserver: ObservableObject {
    @Published var isDraggingGlobal = false
    private var timer: Timer?
    private var pasteboard = NSPasteboard(name: .drag)
    private var lastChangeCount: Int = 0
    init() { lastChangeCount = pasteboard.changeCount; startObserving() }
    func startObserving() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
            let count = self.pasteboard.changeCount
            let pressed = NSEvent.pressedMouseButtons != 0
            if count != self.lastChangeCount && pressed {
                self.lastChangeCount = count
                if !self.isDraggingGlobal { self.isDraggingGlobal = true }
            } else if !pressed && self.isDraggingGlobal { self.isDraggingGlobal = false }
        }
    }
}

struct RootView: View {
    @StateObject var dragObserver = DragObserver()
    @ObservedObject var store: FileStore
    var currentLocale: Locale { store.appLanguage == "system" ? Locale.current : Locale(identifier: store.appLanguage) }
    var body: some View {
        ContentView().environmentObject(dragObserver).environmentObject(store).environment(\.locale, currentLocale)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSPanel!
    var fileStore = FileStore()
    func applicationDidFinishLaunching(_ notification: Notification) {
        let rootView = RootView(store: fileStore)
        window = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 220, height: 320), styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.contentView = NSHostingView(rootView: rootView)
        if let screen = NSScreen.main { window.setFrameOrigin(NSPoint(x: 20, y: 20)) }
        window.makeKeyAndOrderFront(nil)
    }
}

@main
struct ActionApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        MenuBarExtra { MenuBarMenuContent(store: appDelegate.fileStore) } label: { MenuBarLabel(store: appDelegate.fileStore) }
    }
}

struct MenuBarMenuContent: View {
    @ObservedObject var store: FileStore
    var currentLocale: Locale { store.appLanguage == "system" ? Locale.current : Locale(identifier: store.appLanguage) }
    var body: some View {
        VStack {
            Picker("Sprache / Language", selection: $store.appLanguage) {
                Text("System").tag("system")
                Text("English").tag("en")
                Text("Deutsch").tag("de")
                Text("Español").tag("es")
                Text("Français").tag("fr")
                Text("日本語").tag("ja")
            }.pickerStyle(.menu)
            Divider()
            Toggle("Beim Login starten", isOn: $store.launchAtLogin)
            Divider()
            Button("Alle löschen") { store.clearAll() }
            Divider()
            Button("Action beenden") { NSApplication.shared.terminate(nil) }
        }.environment(\.locale, currentLocale)
    }
}

struct MenuBarLabel: View {
    @ObservedObject var store: FileStore
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "tray.and.arrow.down.fill")
            if !store.droppedFileURLs.isEmpty {
                Text("\(store.droppedFileURLs.count)").font(.system(.caption, design: .rounded))
            }
        }
    }
}
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        MenuBarExtra("Action", systemImage: "tray.and.arrow.down.fill") {
            Button("Action beenden") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
