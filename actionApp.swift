import SwiftUI
import AppKit
import Combine

class DragObserver: ObservableObject {
    @Published var isDraggingGlobal = false
    private var timer: Timer?
    private var pasteboard = NSPasteboard(name: .drag)
    private var lastChangeCount: Int = 0

    init() {
        lastChangeCount = pasteboard.changeCount
        startObserving()
    }

    func startObserving() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
            let currentCount = self.pasteboard.changeCount
            let mousePressed = NSEvent.pressedMouseButtons != 0

            if currentCount != self.lastChangeCount && mousePressed {
                self.lastChangeCount = currentCount
                if !self.isDraggingGlobal { self.isDraggingGlobal = true }
            } else if !mousePressed && self.isDraggingGlobal {
                self.isDraggingGlobal = false
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSPanel!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let contentView = ContentView()
            .environmentObject(DragObserver())

        window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 220, height: 300),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.contentView = NSHostingView(rootView: contentView)
        
        if let screen = NSScreen.main {
            let padding: CGFloat = 20
            window.setFrameOrigin(NSPoint(x: padding, y: padding))
        }
        
        window.makeKeyAndOrderFront(nil)
    }
}

@main
struct ActionApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        MenuBarExtra("Action", systemImage: "tray.and.arrow.down.fill") {
            Button("Action beenden") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
