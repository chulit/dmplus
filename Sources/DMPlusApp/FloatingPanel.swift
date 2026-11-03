import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// IDM's floating drop target ("Download Panel"): a small always-on-top
/// box you drop links onto from any app.
@MainActor
final class FloatingPanelController {
    private var panel: NSPanel?

    func toggle(model: DownloadListModel) {
        if let panel, panel.isVisible {
            panel.close()
            return
        }
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 150, height: 110),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.contentView = NSHostingView(rootView: DropPanelView(model: model))
        panel.center()
        panel.orderFront(nil)
        self.panel = panel
    }
}

/// The drop box itself.
struct DropPanelView: View {
    @Bindable var model: DownloadListModel

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 34))
                .foregroundStyle(.tint)
            Text("DM+")
                .font(.headline)
            Text("Jatuhkan URL di sini")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(width: 150, height: 110)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14)
            .stroke(.secondary.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [5])))
        .onDrop(of: [.text, .url], isTargeted: nil) { providers in
            for provider in providers {
                provider.loadObject(ofClass: NSString.self) { object, _ in
                    if let text = object as? String {
                        Task { @MainActor in model.add(urlString: text) }
                    }
                }
            }
            return true
        }
    }
}
