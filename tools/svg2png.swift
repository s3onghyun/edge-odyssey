import AppKit
let a = CommandLine.arguments; let img = NSImage(contentsOf: URL(fileURLWithPath: a[1]))!
let scale = Double(a[3]) ?? 1
let w = Int(img.size.width * scale), h = Int(img.size.height * scale)
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSGraphicsContext.current?.imageInterpolation = .none
img.draw(in: NSRect(x: 0, y: 0, width: w, height: h)); NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: a[2]))
