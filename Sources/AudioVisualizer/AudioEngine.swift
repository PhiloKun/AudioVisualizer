import AVFoundation
import Accelerate

final class AudioEngine: ObservableObject {
    @Published var magnitudes: [Float] = Array(repeating: 0, count: 128)
    @Published var waveform: [Float] = Array(repeating: 0, count: 256)
    @Published var isRunning = false
    @Published var permissionDenied = false
    @Published var inputLevel: Float = 0

    private let fftSize = 2048
    private let fftSetup: vDSP_DFT_Setup
    private let engine = AVAudioEngine()
    private var smoothed: [Float]
    private var pending = [Float]()
    private let procQueue = DispatchQueue(label: "audio.process", qos: .userInitiated)

    init() {
        fftSetup = vDSP_DFT_zop_CreateSetup(
            nil, vDSP_Length(fftSize), vDSP_DFT_Direction.FORWARD
        )!
        smoothed = Array(repeating: 0, count: 128)
    }

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: break
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] ok in
                if ok { DispatchQueue.main.async { self?.startEngine() } }
                else { DispatchQueue.main.async { self?.permissionDenied = true } }
            }
            return
        default:
            permissionDenied = true
            return
        }
        startEngine()
    }

    private func startEngine() {
        let input = engine.inputNode
        let fmt = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: AVAudioFrameCount(fftSize), format: fmt) { [weak self] buf, _ in
            self?.process(buf)
        }
        try? engine.start()
        isRunning = true
    }

    func stop() {
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        pending.removeAll()
        isRunning = false
    }

    private func process(_ buffer: AVAudioPCMBuffer) {
        guard let ch = buffer.floatChannelData?[0] else { return }
        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return }

        // Copy to temp buffer (FFT thread-safe)
        let signal = Array(UnsafeBufferPointer(start: ch, count: min(frames, fftSize)))

        procQueue.async { [weak self] in
            self?.processSamples(signal)
        }
    }

    private func processSamples(_ signal: [Float]) {
        guard !signal.isEmpty else { return }

        var sumSq: Float = 0
        let c = min(signal.count, 1024)
        for i in 0..<c { sumSq += signal[i] * signal[i] }
        let rms = sqrt(sumSq / Float(c))

        pending.append(contentsOf: signal)
        while pending.count >= fftSize {
            let sig = Array(pending.prefix(fftSize))
            pending.removeFirst(fftSize / 2)
            process(sig, rms: rms)
        }
        if pending.count > fftSize * 4 {
            pending.removeFirst(pending.count - fftSize * 4)
        }
    }

    private func process(_ signal: [Float], rms: Float) {
        let n = fftSize
        var window = [Float](repeating: 0, count: n)
        vDSP_hann_window(&window, vDSP_Length(n), Int32(vDSP_HANN_NORM))
        var sig = signal
        vDSP_vmul(sig, 1, window, 1, &sig, 1, vDSP_Length(n))

        var wf = [Float](repeating: 0, count: 256)
        for i in 0..<256 { wf[i] = sig[i * n / 256] }

        let zeros = [Float](repeating: 0, count: n)
        var realOut = [Float](repeating: 0, count: n)
        var imagOut = [Float](repeating: 0, count: n)
        vDSP_DFT_Execute(fftSetup, sig, zeros, &realOut, &imagOut)

        let half = n / 2
        var mags = [Float](repeating: 0, count: half)
        for i in 0..<half { mags[i] = sqrt(realOut[i] * realOut[i] + imagOut[i] * imagOut[i]) }

        let maxBin = half
        var bands = [Float](repeating: 0, count: 128)
        for i in 0..<128 {
            let t0 = Float(i) / 128.0
            let t1 = Float(i + 1) / 128.0
            let start = i == 0 ? 1 : Int(pow(Float(maxBin), t0))
            let end = Int(pow(Float(maxBin), t1))
            let cnt = max(end - start, 1)
            var sum: Float = 0
            for j in start..<min(end, maxBin) { sum += mags[j] }
            bands[i] = sum / Float(cnt)
        }

        let minDb: Float = -60, maxDb: Float = 0
        var db = [Float](repeating: 0, count: 128)
        for i in 0..<128 {
            let v = bands[i]
            db[i] = v > 0 ? 20 * log10(v) : minDb
            db[i] = (db[i] - minDb) / (maxDb - minDb)
            db[i] = max(0, min(1, db[i]))
        }
        let attack: Float = 0.35, release: Float = 0.15
        for i in 0..<128 {
            let rate = db[i] >= smoothed[i] ? attack : release
            smoothed[i] = rate * db[i] + (1 - rate) * smoothed[i]
        }
        let ms = smoothed
        let wave = wf
        let level = min(1, rms * 4)

        Task { @MainActor in
            self.magnitudes = ms
            self.waveform = wave
            self.inputLevel = level
        }
    }
}
