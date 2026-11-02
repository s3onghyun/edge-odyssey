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

// MARK: - welcome guide

struct WelcomeView: View {
    let character: URL?
    /// Installs the hook scripts and copies the settings snippet; returns a status line.
    let copyHookSnippet: () -> String
    let setLoginItem: (Bool) -> Void
    let finish: (_ startFocus: Bool) -> Void

    @State private var page = 0
    @State private var copied: String?
    @State private var login = LoginItem.isOn

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch page {
                case 0: voyage
                case 1: claude
                default: quiet
                }
            }
            .frame(width: 480, height: 330, alignment: .topLeading)
            .padding(.horizontal, 28)
            .padding(.top, 24)
            Divider()
            HStack {
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle().fill(i == page ? Color.accentColor : Color.secondary.opacity(0.3)).frame(width: 7, height: 7)
                    }
                }
                Spacer()
                if page > 0 { Button("Back") { page -= 1 } }
                if page < 2 {
                    Button("Next") { page += 1 }.keyboardShortcut(.defaultAction)
                } else {
                    Button("Close") { finish(false) }
                    Button("Start a focus voyage") { finish(true) }.keyboardShortcut(.defaultAction)
                }
            }
            .padding(16)
        }
    }

    private func art(_ svg: String, height: CGFloat = 78) -> some View {
        Group {
            if let url = character?.appendingPathComponent(svg + ".svg"), let img = NSImage(contentsOf: url) {
                Image(nsImage: img).resizable().aspectRatio(32.0 / 26.0, contentMode: .fit).frame(height: height)
                    .accessibilityHidden(true)   // decoration
            }
        }
    }

    private func title(_ t: String) -> some View {
        Text(t).font(.system(size: 22, weight: .bold, design: .rounded))
    }

    private var voyage: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom, spacing: 18) {
                art("walk-1"); art("climb-crag-1"); art("slide-0")
            }
            title("A voyage around your screen")
            Text("Start a focus from the menu bar (25 minutes, or another length under Timer). Odysseus rows along the bottom edge, climbs the right, hangs from the top and slides down the left, arriving home exactly when time is up. The trail behind him is your progress; breaks are short visits to Ithaca.")
            VStack(alignment: .leading, spacing: 4) {
                Label("Mode: Odysseus voyage, or a thin border only", systemImage: "sailboat")
                Label("Show on: main display, all displays, or the one you work on", systemImage: "display.2")
                Label("Border 2-4 px, or show only in the last 5 minutes", systemImage: "square.dashed")
            }
            .font(.callout).foregroundStyle(.secondary)
        }
    }

    private var claude: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom, spacing: 18) { art("sirens-1"); art("storm-1") }
            title("Claude Code signals (optional)")
            Text("With a small hook, the edge tells you what Claude Code is doing: a quiet blue edge while it works, the Sirens and one soft gold swell when it waits for you, and Poseidon's storm near the 5-hour limit. Nothing leaves your Mac.")
            HStack(spacing: 12) {
                Button("Copy hook snippet") { copied = copyHookSnippet() }
                if let copied { Text(copied).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
            }
            Text("Then paste it into ~/.claude/settings.json yourself (merge it with any \"hooks\" you already have). Edge Odyssey never edits that file. Already have a statusLine? Keep yours and set EDGE_ODYSSEY_STATUSLINE_NEXT to it.")
                .font(.callout).foregroundStyle(.secondary)
        }
    }

    private var quiet: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom, spacing: 18) { art("doze-0"); art("ithaca-0") }
            title("Out of your way")
            Text("The edge never takes a click. It hides in full-screen apps and while your screen is shared or recorded, and Control-Option-Command-H hides it any time. Episodes from the Odyssey fill a 24-book logbook as you focus.")
            Toggle("Launch Edge Odyssey at login", isOn: $login)
                .onChange(of: login) { setLoginItem($0); login = LoginItem.isOn }
            Text("Off unless you turn it on. You can change it later under Settings in the menu.")
                .font(.callout).foregroundStyle(.secondary)
        }
    }
}
