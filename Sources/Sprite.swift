import AppKit

/// One animation of a character: discrete frames played at `fps`.
struct SpriteAnim {
    let fps: Double
    let frames: [CGImage]
    var duration: Double { Double(frames.count) / fps }
}

/// A character loaded from a hand-editable `.sprite` text grid (see assets/characters).
/// Frames are rendered at 1 image pixel per sprite pixel; layers magnify them with
/// nearest-neighbour filtering so they stay crisp at any integer device-pixel scale.
///
/// The same interface also loads a clean-vector character: a folder with `character.txt`
/// (name, size, `anim: <name> fps=<n> frames=a.svg,b.svg`) and SVG frames, rasterised once
/// at launch. Art can be swapped without touching the app code.
final class SpriteSheet {
    let id: String
    private(set) var name = ""
    private(set) var width = 0
    private(set) var height = 0
    private(set) var anims: [String: SpriteAnim] = [:]
    /// Pixel art is magnified with nearest-neighbour; vector frames are smooth.
    private(set) var pixelated = true
    /// Device pixels per sprite pixel for pixel art (header `pixel: N`, default 3).
    private(set) var devicePixels = 3

    /// Size of one sprite unit in points on a display with this backing scale.
    func unitPoints(backing: CGFloat) -> CGFloat {
        pixelated ? CGFloat(devicePixels) / max(backing, 1) : 1
    }

    /// Loads a `.sprite` grid file, or a vector character folder.
    convenience init(url: URL) throws {
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        if isDir.boolValue { try self.init(vectorFolder: url) } else { try self.init(gridFile: url) }
    }

    init(vectorFolder url: URL) throws {
        id = url.lastPathComponent
        pixelated = false
        let text = try String(contentsOf: url.appendingPathComponent("character.txt"), encoding: .utf8)
        // Rasterise at the sharpest display's backing scale: 1 pt per unit maps 1:1 to pixels.
        let renderScale = Int(NSScreen.screens.map(\.backingScaleFactor).max() ?? 2)
        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("name:") {
                name = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("size:") {
                let p = line.dropFirst(5).trimmingCharacters(in: .whitespaces).split(separator: "x")
                width = Int(p[0]) ?? 0
                height = Int(p[1]) ?? 0
            } else if line.hasPrefix("anim:") {
                let parts = line.dropFirst(5).split(separator: " ")
                let fps = parts.first { $0.hasPrefix("fps=") }.flatMap { Double($0.dropFirst(4)) } ?? 4
                let files = parts.first { $0.hasPrefix("frames=") }.map { $0.dropFirst(7).split(separator: ",") } ?? []
                let frames = files.compactMap { f -> CGImage? in
                    guard let img = NSImage(contentsOf: url.appendingPathComponent(String(f))) else { return nil }
                    let r = CGRect(x: 0, y: 0, width: width * renderScale, height: height * renderScale)
                    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(r.width), pixelsHigh: Int(r.height),
                                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
                    NSGraphicsContext.saveGraphicsState()
                    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
                    img.draw(in: r)
                    NSGraphicsContext.restoreGraphicsState()
                    return rep.cgImage
                }
                if !frames.isEmpty { anims[String(parts[0])] = SpriteAnim(fps: fps, frames: frames) }
            }
        }
        guard width > 0, height > 0, anims["walk"] != nil else {
            throw NSError(domain: "Sprite", code: 2, userInfo: [NSLocalizedDescriptionKey: "bad vector character \(url.path)"])
        }
    }

    init(gridFile url: URL) throws {
        id = url.deletingPathExtension().lastPathComponent
        let text = try String(contentsOf: url, encoding: .utf8)
        var palette: [Character: CGColor] = [:]
        var inPalette = false
        var currentAnim: (name: String, fps: Double)?
        var frames: [[String]] = []
        var frame: [String]?

        func flushFrame() {
            if let f = frame { frames.append(f) }
            frame = nil
        }
        func flushAnim() {
            flushFrame()
            if let a = currentAnim, !frames.isEmpty {
                anims[a.name] = SpriteAnim(fps: a.fps, frames: frames.map { render($0, palette) })
            }
            frames = []
        }

        for raw in text.components(separatedBy: .newlines) {
            if raw.hasPrefix("#") || raw.trimmingCharacters(in: .whitespaces).isEmpty { continue }
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("name:") {
                name = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("size:") {
                let p = line.dropFirst(5).trimmingCharacters(in: .whitespaces).split(separator: "x")
                width = Int(p[0]) ?? 0
                height = Int(p[1]) ?? 0
            } else if line.hasPrefix("pixel:") {
                devicePixels = Int(line.dropFirst(6).trimmingCharacters(in: .whitespaces)) ?? 3
            } else if line == "palette:" {
                inPalette = true
            } else if line.hasPrefix("anim:") {
                inPalette = false
                flushAnim()
                let parts = line.dropFirst(5).split(separator: " ")
                let fps = parts.first { $0.hasPrefix("fps=") }.flatMap { Double($0.dropFirst(4)) } ?? 4
                currentAnim = (String(parts[0]), fps)
            } else if line == "frame:" {
                flushFrame()
                frame = []
            } else if inPalette {
                let parts = line.split(separator: " ")
                if parts.count >= 2, let key = parts[0].first, let c = Self.color(String(parts[1])) {
                    palette[key] = c
                }
            } else if frame != nil {
                frame!.append(line)
            }
        }
        flushAnim()
        guard width > 0, height > 0, anims["walk"] != nil else {
            throw NSError(domain: "Sprite", code: 1, userInfo: [NSLocalizedDescriptionKey: "bad sprite \(url.path)"])
        }
    }

    private func render(_ rows: [String], _ palette: [Character: CGColor]) -> CGImage {
        let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        for (r, row) in rows.enumerated() {
            for (c, ch) in row.enumerated() where ch != "." {
                guard let color = palette[ch] else { continue }
                ctx.setFillColor(color)
                ctx.fill(CGRect(x: c, y: height - 1 - r, width: 1, height: 1))
            }
        }
        return ctx.makeImage()!
    }

    static func color(_ hex: String) -> CGColor? {
        guard hex.hasPrefix("#"), hex.count == 7, let v = Int(hex.dropFirst(), radix: 16) else { return nil }
        return CGColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
                       blue: CGFloat(v & 0xFF) / 255, alpha: 1)
    }

    /// Writes every animation as a PNG strip (nearest-neighbour scaled) - used for previews.
    func exportPNGs(to dir: URL, scale: Int) throws {
        for (anim, a) in anims {
            let w = width * scale * a.frames.count, h = height * scale
            let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            ctx.interpolationQuality = pixelated ? .none : .high
            for (i, f) in a.frames.enumerated() {
                ctx.draw(f, in: CGRect(x: i * width * scale, y: 0, width: width * scale, height: h))
            }
            let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
            let url = dir.appendingPathComponent("\(id)-\(anim)@\(scale)x.png")
            try rep.representation(using: .png, properties: [:])!.write(to: url)
        }
    }
}
