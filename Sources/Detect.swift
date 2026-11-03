import AppKit
import CoreGraphics

/// Best-effort "someone may be watching this screen" detection.
///
/// * Screen capture / sharing: while any app captures the screen (ScreenCaptureKit, Zoom,
///   Meet in a browser, QuickTime, screencapture -v ...), macOS shows its privacy indicator,
///   which appears in the window list as a tiny Window Server window named "StatusIndicator".
///   Window names need the Screen Recording permission; without it we fall back to the
///   shape (tiny Window Server window at the top of a display). Undocumented: may change.
/// * Full screen: the overlay never joins another app's full-screen space. Windows that
///   cover a whole display without being a full-screen space (slideshows, players) are
///   caught by comparing window bounds with display bounds.
final class Detector {
    struct Result: Equatable {
        var capturing = false
        var coveredDisplays: Set<CGDirectDisplayID> = []
        var activeDisplay: CGDirectDisplayID?   // display holding the frontmost app's front window
    }

    private(set) var result = Result()
    private var timer: Timer?
    var onChange: ((Result) -> Void)?
    var log: ((String) -> Void)?

    func start(interval: TimeInterval = 2) {
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in self?.poll() }
        timer?.tolerance = interval / 2
        let nc = NSWorkspace.shared.notificationCenter
        for n in [NSWorkspace.activeSpaceDidChangeNotification, NSWorkspace.didActivateApplicationNotification] {
            nc.addObserver(forName: n, object: nil, queue: .main) { [weak self] _ in self?.poll() }
        }
        poll()
    }

    func poll() {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else { return }
        let me = ProcessInfo.processInfo.processIdentifier
        let front = NSWorkspace.shared.frontmostApplication?.processIdentifier
        var r = Result()
        var why: [String] = []
        let displays = NSScreen.screens.compactMap { s -> (CGDirectDisplayID, CGRect)? in
            guard let id = s.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else { return nil }
            return (id, CGDisplayBounds(id))
        }
        for w in list {
            let owner = w[kCGWindowOwnerName as String] as? String ?? ""
            let pid = w[kCGWindowOwnerPID as String] as? Int32 ?? 0
            let layer = w[kCGWindowLayer as String] as? Int ?? 0
            let name = w[kCGWindowName as String] as? String
            let alpha = w[kCGWindowAlpha as String] as? Double ?? 1
            guard let bd = w[kCGWindowBounds as String] as? NSDictionary,
                  let b = CGRect(dictionaryRepresentation: bd) else { continue }
            if owner == "Window Server" {
                if name == "StatusIndicator" {
                    r.capturing = true
                    why.append("indicator \(Int(b.minX)),\(Int(b.minY)) \(Int(b.width))x\(Int(b.height))")
                } else if name == nil, b.width <= 32, b.height <= 32,
                          displays.contains(where: { abs(b.minY - $0.1.minY) < 6 }) {
                    r.capturing = true   // no Screen Recording permission: match by shape
                    why.append("unnamed tiny window \(Int(b.width))x\(Int(b.height))")
                }
                continue
            }
            // Notification Center hosts banners in a clear window the size of the display: a banner
            // (our own arrival notice included) covers nothing.
            guard pid != me, layer >= 0, alpha > 0.05, owner != "Notification Center" else { continue }
            if r.activeDisplay == nil, pid == front, layer == 0, b.width > 80, b.height > 80 {
                // window list is front-to-back: the first normal window of the active app
                let c = CGPoint(x: b.midX, y: b.midY)
                r.activeDisplay = displays.first { $0.1.contains(c) }?.0
            }
            for (id, frame) in displays where b.equalTo(frame) || (b.contains(frame) && layer > 0) {
                r.coveredDisplays.insert(id)
                why.append("cover d\(id) by \(owner) L\(layer)")
            }
        }
        if r != result {
            result = r
            log?("detector: capturing=\(r.capturing) covered=\(r.coveredDisplays.sorted()) active=\(r.activeDisplay.map(String.init) ?? "-") [\(why.joined(separator: "; "))]")
            onChange?(r)
        }
    }
}
