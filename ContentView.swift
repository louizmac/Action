import SwiftUI
import UniformTypeIdentifiers
import Combine

struct ContentView: View {
    @EnvironmentObject var dragObserver: DragObserver
    @State private var droppedFileURLs: [URL] = []
    @State private var isTargeted = false

    var isVisible: Bool {
        dragObserver.isDraggingGlobal || !droppedFileURLs.isEmpty
    }

    var body: some View {
        ZStack {
            VisualEffectView(material: .popover, blendingMode: .behindWindow)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: Color.black.opacity(0.15), radius: 15, x: 0, y: 8)
            
            VStack(spacing: 0) {
                if droppedFileURLs.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "plus.viewfinder")
                            .font(.system(size: 30, weight: .light))
                            .foregroundColor(.secondary)
                        Text("Dateien ablegen")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 10) {
                            ForEach(droppedFileURLs, id: \.self) { url in
                                FileRow(url: url) {
                                    droppedFileURLs.removeAll { $0 == url }
                                }
                            }
                        }
                        .padding(12)
                    }
                }
            }
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(isTargeted ? Color.accentColor : Color.clear, lineWidth: 3)
                .padding(2)
        }
        .frame(width: 220, height: 300)
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1.0 : 0.95)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isVisible)
        
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url = url {
                        DispatchQueue.main.async {
                            if !droppedFileURLs.contains(url) {
                                withAnimation(.spring()) {
                                    droppedFileURLs.append(url)
                                }
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
    let url: URL
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .frame(width: 28, height: 28)
            
            Text(url.lastPathComponent)
                .font(.system(size: 12, weight: .regular))
                .lineLimit(1)
                .truncationMode(.middle)
            
            Spacer()
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(Color.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onDrag {
            NSItemProvider(object: url as NSURL)
        }
    }
}

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) { }
}
