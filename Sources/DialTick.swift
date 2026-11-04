import AVFoundation
import Foundation

/// The small, synthesized mechanism sound used while setting the focus dial.  Its decision
/// rules are pure so a fast drag cannot turn into a queue of old clicks after the dial stops.
enum DialTick {
    enum Kind: Equatable { case minute, detent }

    /// Never schedule more than one click in this interval. It is short enough to feel attached
    /// to a deliberate wheel step, while a trackpad fling stays quiet and responsive.
    static let minimumInterval: TimeInterval = 0.045

    /// A dial movement may cross several values (for example a trackpad event).  It remains one
    /// audible event; the gate below is what keeps a stream of such events from piling up.
    static func kind(from: Double, to: Double) -> Kind? {
        let a = Int(from.rounded()), b = Int(to.rounded())
        guard a != b else { return nil }
        let range = min(a, b)...max(a, b)
        return Dial.detents.contains { range.contains(Int($0)) } ? .detent : .minute
    }

    static func mayPlay(at now: TimeInterval, after last: TimeInterval?) -> Bool {
        guard let last else { return true }
        // `systemUptime` is a Double; allow one microsecond so an exact 45 ms boundary is not
        // rejected by binary rounding.
        return now - last >= minimumInterval - 0.000_001
    }
}

/// A tiny mechanical click made from two quickly damped oscillators.  Keeping both PCM buffers
/// ready means dragging the dial never has to decode a file or allocate audio on its input path.
final class DialTickSound {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format: AVAudioFormat
    private let minute: AVAudioPCMBuffer
    private let detent: AVAudioPCMBuffer

    init() {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        self.format = format
        minute = Self.buffer(format: format, frames: 720, heavy: false)
        detent = Self.buffer(format: format, frames: 1_180, heavy: true)
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        engine.prepare()
        try? engine.start()
    }

    func warm() { _ = engine.isRunning }

    func play(_ kind: DialTick.Kind, volume: Float) {
        if !engine.isRunning { try? engine.start() }
        player.volume = volume
        player.scheduleBuffer(kind == .detent ? detent : minute, completionHandler: nil)
        if !player.isPlaying { player.play() }
    }

    private static func buffer(format: AVAudioFormat, frames: AVAudioFrameCount, heavy: Bool) -> AVAudioPCMBuffer {
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        let samples = buffer.floatChannelData![0], rate = Float(format.sampleRate)
        for i in 0..<Int(frames) {
            let t = Float(i) / rate
            let envelope = exp(-t * (heavy ? 115 : 180))
            let body = sin(2 * .pi * (heavy ? 1_450 : 1_850) * t)
            let snap = sin(2 * .pi * (heavy ? 3_100 : 3_700) * t)
            samples[i] = envelope * (0.58 * body + 0.18 * snap) * (heavy ? 0.9 : 0.65)
        }
        return buffer
    }
}
