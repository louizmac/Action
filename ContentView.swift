import SwiftUI
import UniformTypeIdentifiers
import QuickLookThumbnailing

struct ContentView: View {
    @EnvironmentObject var dragObserver: DragObserver
    @EnvironmentObject var store: FileStore
    @State private var isTargeted = false

    var isVisible: Bool { dragObserver.isDraggingGlobal || !store.droppedFileURLs.isEmpty }

    var body: some View {
        ZStack {
            VisualEffectView(material: .popover, blendingMode: .behindWindow)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: Color.black.opacity(0.15), radius: 15, x: 0, y: 8)
            
            VStack(spacing: 0) {
                if store.droppedFileURLs.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "plus.viewfinder").font(.system(size: 30, weight: .light)).foregroundColor(.secondary)
                        Text("Dateien ablegen").font(.system(size: 13, weight: .medium)).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 10) {
                            ForEach(store.droppedFileURLs, id: \.self) { url in
                                FileRow(url: url)
                            }
                        }
                        .padding(12)
                        .padding(.bottom, store.droppedFileURLs.count >= 2 ? 50 : 0)
                    }
                }
            }
            
            let removableCount = store.droppedFileURLs.filter { !store.isPinned($0) }.count
            if removableCount >= 2 {
                VStack {
                    Spacer()
                    Button(action: { store.clearAll() }) {
                        Label("Alle löschen", systemImage: "trash")
                            .font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                            .padding(.vertical, 6).padding(.horizontal, 12)
                            .background(Color.red.opacity(0.8)).clipShape(Capsule())
                    }
                    .buttonStyle(.plain).padding(.bottom, 16).transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            
            RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(isTargeted ? Color.accentColor : Color.clear, lineWidth: 3).padding(2)
        }
        .frame(width: 220, height: 320)
        .opacity(isVisible ? 1 : 0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isVisible)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url = url {
                        DispatchQueue.main.async {
                            if !store.droppedFileURLs.contains(url) {
                                withAnimation(.spring()) { store.droppedFileURLs.append(url) }
                            }
                        }
                    }
                }
            }
            return true
        }
    }
}

struct FileRow: View {
    @EnvironmentObject var store: FileStore
    let url: URL
    @State private var isHoveringIcon = false
    @State private var thumbnail: NSImage? = nil
    @State private var fileSizeString: String = ""
    
    var isMedia: Bool {
        let uti = UTType(filenameExtension: url.pathExtension)
        return uti?.conforms(to: .image) == true || uti?.conforms(to: .movie) == true
    }
    
    var body: some View {
        HStack(spacing: 10) {
            Button(action: { NSWorkspace.shared.open(url) }) {
                ZStack(alignment: .topTrailing) {
                    Group {
                        if let thumb = thumbnail {
                            Image(nsImage: thumb).resizable().aspectRatio(contentMode: .fill).frame(width: 28, height: 28).clipShape(RoundedRectangle(cornerRadius: 4))
                        } else {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable().aspectRatio(contentMode: .fit).frame(width: 28, height: 28)
                        }
                    }
                    
                    if store.isPinned(url) {
                        Circle().fill(Color.accentColor).frame(width: 6, height: 6).offset(x: 2, y: -2)
                    }
                }
            }
            .buttonStyle(.plain)
            .scaleEffect(isHoveringIcon && isMedia ? 3.5 : 1.0, anchor: .leading)
            .onHover { h in isHoveringIcon = h; if h && isMedia { NSCursor.pointingHand.push() } else { NSCursor.pop() } }
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHoveringIcon)
            .zIndex(10)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(url.lastPathComponent).font(.system(size: 11, weight: .medium)).lineLimit(1)
                Text(fileSizeString).font(.system(size: 9)).foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button(action: { store.togglePin(for: url) }) {
                    Image(systemName: store.isPinned(url) ? "pin.fill" : "pin")
                        .font(.system(size: 10))
                        .foregroundColor(store.isPinned(url) ? .accentColor : .secondary)
                        .rotationEffect(.degrees(store.isPinned(url) ? 0 : 45))
                }
                .buttonStyle(.plain)
                .help("Anpinnen")

                Button(action: { copyFileToClipboard() }) {
                    Image(systemName: "doc.on.doc").font(.system(size: 11)).foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Kopieren")
                
                Button(action: { showShareMenu() }) {
                    Image(systemName: "square.and.arrow.up").font(.system(size: 11)).foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                
                Button(action: { store.remove(url: url) }) {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 11)).foregroundColor(.secondary.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(store.isPinned(url) ? Color.accentColor.opacity(0.08) : Color.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contextMenu {
            Button(store.isPinned(url) ? "Loslösen" : "Anpinnen") { store.togglePin(for: url) }
            Divider()
            Button("Im Finder anzeigen") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
            Button("Pfad kopieren") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(url.path, forType: .string) }
            Divider()
            Button("Entfernen", role: .destructive) { store.remove(url: url) }
        }
        .onDrag { NSItemProvider(object: url as NSURL) }
        .zIndex(isHoveringIcon ? 100 : 0)
        .task { if isMedia { await loadThumbnail() }; loadFileAttributes() }
    }
    
    func copyFileToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([url as NSURL])
    }
    
    func showShareMenu() {
        let picker = NSSharingServicePicker(items: [url])
        if let window = NSApplication.shared.windows.first {
            picker.show(relativeTo: .zero, of: window.contentView!, preferredEdge: .minY)
        }
    }

    private func loadFileAttributes() {
        if let res = try? url.resourceValues(forKeys: [.fileSizeKey]), let size = res.fileSize {
            let selectedLocale = store.appLanguage == "system" ? Locale.current : Locale(identifier: store.appLanguage)
            fileSizeString = Int64(size).formatted(.byteCount(style: .file).locale(selectedLocale))
        }
    }

    private func loadThumbnail() async {
        let req = QLThumbnailGenerator.Request(fileAt: url, size: CGSize(width: 100, height: 100), scale: 2.0, representationTypes: .thumbnail)
        if let res = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: req) {
            await MainActor.run { self.thumbnail = res.nsImage }
        }
    }
}

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView(); v.material = material; v.blendingMode = blendingMode; v.state = .active; return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
