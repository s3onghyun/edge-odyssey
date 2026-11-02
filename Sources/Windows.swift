import AppKit
import SwiftUI

// The two ordinary windows: the logbook and the first-run welcome guide.

/// Opens (or brings back) a small titled window hosting a SwiftUI view.
final class PanelWindow {
    private var window: NSWindow?

    func show<V: View>(title: String, _ view: V) {
        let w = window ?? NSWindow(contentRect: .zero, styleMask: [.titled, .closable, .miniaturizable],
                                   backing: .buffered, defer: false)
        w.title = title
        w.isReleasedWhenClosed = false
        w.contentView = NSHostingView(rootView: view)
        w.setContentSize(w.contentView!.fittingSize)
        if window == nil { w.center() }
        window = w
        NSApp.activate(ignoringOtherApps: true)   // a menu-bar app has to bring itself forward
        w.makeKeyAndOrderFront(nil)
    }

    func close() { window?.close() }
}

// MARK: - logbook

/// Art for a found book: frames of the character and its episode props, layered as on screen.
/// Offsets are in sprite widths (x, right) and heights (y, up).
private let bookArt: [Int: [(svg: String, x: CGFloat, y: CGFloat)]] = [
    1: [("walk-1", -0.3, 0), ("ep-owl-0", 0.3, 0.1)],
    5: [("storm-1", 0, 0)],
    9: [("walk-0", -0.45, 0), ("ep-cyclops-4", 0.45, 0)],
    10: [("walk-2", 0.25, 0), ("ep-bag-3", -0.45, 0)],
    12: [("sirens-1", 0, 0)],
    13: [("ithaca-0", 0, 0)],
    17: [("ithaca-2", 0, 0)],
]

struct LogbookView: View {
    let found: [Int: Date]
    let character: URL?   // vector character folder

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Logbook").font(.system(size: 22, weight: .bold, design: .rounded))
                Text("\(found.count) of 24 books found. Episodes happen during focus sessions; each one charts a book of the Odyssey.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Grid(horizontalSpacing: 10, verticalSpacing: 10) {   // not lazy: the window sizes to fit it
                ForEach(0..<4, id: \.self) { row in
                    GridRow { ForEach(1...6, id: \.self) { col in card(row * 6 + col).frame(width: 118) } }
                }
            }
            Text("Books without a voyage yet are uncharted waters: later versions add more episodes.")
                .font(.caption).foregroundStyle(.tertiary)
        }
        .padding(20)
    }

    @ViewBuilder private func card(_ b: Int) -> some View {
        let date = found[b]
        let findable = Episode.findableBooks.contains(b)
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(date != nil ? Color(red: 0.23, green: 0.12, blue: 0.25) : Color.secondary.opacity(0.08))
                if date != nil, let art = bookArt[b], let folder = character {
                    ZStack {
                        ForEach(art.indices, id: \.self) { i in
                            if let img = NSImage(contentsOf: folder.appendingPathComponent(art[i].svg + ".svg")) {
                                Image(nsImage: img).resizable().frame(width: 64, height: 52)
                                    .offset(x: art[i].x * 64, y: -art[i].y * 52)
                            }
                        }
                    }
                } else {
                    Text(findable ? "?" : "~").font(.system(size: 26, weight: .semibold, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(width: 118, height: 70)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            Text("Book \(b)").font(.caption.bold())
            Text(Episode.bookTitles[b] ?? "").font(.caption2).multilineTextAlignment(.center)
                .lineLimit(2, reservesSpace: true)
            Text(date.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? (findable ? "not yet found" : "uncharted"))
                .font(.caption2).foregroundStyle(.secondary)
        }
        .opacity(date != nil ? 1 : findable ? 0.75 : 0.45)
        .accessibilityElement(children: .combine)
    }
}
