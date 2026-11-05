import SwiftUI
#if os(macOS)
import AppKit
#endif

enum MenuBarItem: Hashable {
    case metric(String, String)   // SF Symbol + value
    case icon(String)
    case plug(online: Bool)
}

/// Monochrome label content; only alpha matters in a template image.
struct MenuBarLabel: View {
    let items: [MenuBarItem]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(items, id: \.self) { item in
                switch item {
                case .metric(let symbol, let value):
                    HStack(spacing: 3) {
                        Image(systemName: symbol)
                        Text(value).monospacedDigit()
                    }
                case .icon(let symbol):
                    Image(systemName: symbol)
                case .plug(let online):
                    PlugIcon(online: online)
                }
            }
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.black)
        .padding(.horizontal, 1)
        .frame(height: 18)
    }
}

/// Power plug; crossed out when the grid is off (SF Symbols has no slashed plug).
struct PlugIcon: View {
    let online: Bool

    var body: some View {
        Image(systemName: "powerplug.fill")
            .overlay {
                if !online {
                    GeometryReader { geo in
                        let line = Path { p in
                            p.move(to: CGPoint(x: 0, y: 0))
                            p.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                        }
                        ZStack {
                            // Cut a gap around the slash so it reads clearly
                            line.stroke(style: StrokeStyle(lineWidth: 4.5, lineCap: .round))
                                .blendMode(.destinationOut)
                            line.stroke(style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                        }
                    }
                }
            }
            .compositingGroup()
    }
}

#if os(macOS)
extension MenuBarLabel {
    /// Renders the label as a template image (MenuBarExtra drops SF Symbols
    /// interpolated into Text, so the label is drawn as a picture instead).
    @MainActor
    static func image(_ items: [MenuBarItem]) -> NSImage {
        let renderer = ImageRenderer(content: MenuBarLabel(items: items))
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        let image = renderer.nsImage ?? NSImage(systemSymbolName: "sun.max", accessibilityDescription: nil)!
        image.isTemplate = true   // follows the menu bar's light/dark tint
        return image
    }
}
#endif
