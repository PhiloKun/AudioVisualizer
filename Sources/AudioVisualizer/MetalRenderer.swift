import MetalKit

enum VisMode: String, CaseIterable {
    case bars, circle, wave
}

final class MetalRenderer: NSObject, MTKViewDelegate {
    let view: MTKView
    var magnitudes: [Float] = []
    var waveform: [Float] = []
    var mode: VisMode = .bars

    private let device: MTLDevice
    private let cmdQueue: MTLCommandQueue
    private let pipeline: MTLRenderPipelineState

    init(view: MTKView) {
        self.view = view
        self.device = view.device ?? MTLCreateSystemDefaultDevice()!
        self.cmdQueue = device.makeCommandQueue()!

        let lib = try! device.makeLibrary(source: shaderSource, options: nil)
        let vs = lib.makeFunction(name: "vertexShader")!
        let fs = lib.makeFunction(name: "fragmentShader")!
        let desc = MTLRenderPipelineDescriptor()
        desc.vertexFunction = vs
        desc.fragmentFunction = fs
        desc.colorAttachments[0].pixelFormat = view.colorPixelFormat
        self.pipeline = try! device.makeRenderPipelineState(descriptor: desc)

        super.init()
        view.device = device
        view.delegate = self
        view.enableSetNeedsDisplay = true
        view.isPaused = true
        view.clearColor = MTLClearColorMake(0.02, 0.02, 0.06, 1.0)
        view.framebufferOnly = true
    }

    // MARK: - Vertex Generation

    private func buildVertices(size: CGSize) -> [Float] {
        let w = Float(size.width)
        let h = Float(size.height)
        var verts: [Float] = []
        switch mode {
        case .bars:     buildBars(&verts, w: w, h: h)
        case .circle:   buildCircle(&verts, w: w, h: h)
        case .wave:     buildWave(&verts, w: w, h: h)
        }
        return verts
    }

    /// Dynamic HSV-based color. hue cycles based on index, saturation/value modulated by magnitude
    private func hsvColor(_ i: Int, _ mag: Float, _ total: Int, _ sat: Float = 0.85, _ val: Float = 0.95) -> (r: Float, g: Float, b: Float) {
        let hue = (Float(i) / Float(total) * 0.85 + 0.0).truncatingRemainder(dividingBy: 1.0)
        // Convert HSV to RGB
        let c = val * sat * min(1, mag * 1.5 + 0.15)
        let hp = hue * 6.0
        let x = c * (1 - abs((hp.truncatingRemainder(dividingBy: 2.0)) - 1))
        let m = val * (1 - sat) * min(1, mag * 1.5 + 0.15)
        let (r1, g1, b1): (Float, Float, Float)
        switch Int(hp) {
        case 0: (r1, g1, b1) = (c, x, 0)
        case 1: (r1, g1, b1) = (x, c, 0)
        case 2: (r1, g1, b1) = (0, c, x)
        case 3: (r1, g1, b1) = (0, x, c)
        case 4: (r1, g1, b1) = (x, 0, c)
        case 5: (r1, g1, b1) = (c, 0, x)
        default: (r1, g1, b1) = (0, 0, 0)
        }
        return (r1 + m, g1 + m, b1 + m)
    }

    private func buildBars(_ v: inout [Float], w: Float, h: Float) {
        let barW = w / 128.0
        let gap: Float = 1.5

        for i in 0..<128 {
            let mag = i < magnitudes.count ? magnitudes[i] : 0
            let barH = mag * h * 0.82
            let x0 = Float(i) * barW + gap * 0.5
            let x1 = x0 + barW - gap
            let yBot: Float = 0
            let yTop = max(barH, 0)
            let (r, g, b) = hsvColor(i, mag, 128)

            // Top vertices get brighter color (gradient effect via vertex color)
            // Bottom: dimmer version
            let dim: Float = 0.3
            let rd = r * dim, gd = g * dim, bd = b * dim

            // Two triangles for a rectangle
            // Bottom-left, bottom-right, top-right
            v += [x0, yBot, rd, gd, bd, 1,  x1, yBot, rd, gd, bd, 1,  x1, yTop, r, g, b, 1]
            // Bottom-left, top-right, top-left
            v += [x0, yBot, rd, gd, bd, 1,  x1, yTop, r, g, b, 1,  x0, yTop, r, g, b, 1]
        }
    }

    private func buildCircle(_ v: inout [Float], w: Float, h: Float) {
        let cx = w / 2
        let cy = h / 2
        let baseR: Float = 80
        let barW: Float = 5

        for i in 0..<128 {
            let mag = i < magnitudes.count ? magnitudes[i] : 0
            let angle = Float(i) / 128.0 * 2.0 * .pi - .pi / 2.0
            let barLen = mag * 120
            let cosA = cos(angle)
            let sinA = sin(angle)
            let (r, g, b) = hsvColor(i, mag, 128)

            let x0 = cosA * (baseR - barW) - sinA * barW + cx
            let y0 = sinA * (baseR - barW) + cosA * barW + cy
            let x1 = cosA * (baseR + barLen) - sinA * barW + cx
            let y1 = sinA * (baseR + barLen) + cosA * barW + cy
            let x2 = cosA * (baseR + barLen) + sinA * barW + cx
            let y2 = sinA * (baseR + barLen) - cosA * barW + cy
            let x3 = cosA * (baseR - barW) + sinA * barW + cx
            let y3 = sinA * (baseR - barW) - cosA * barW + cy

            v += [x0, y0, r, g, b, 1,  x1, y1, r, g, b, 1,  x2, y2, r, g, b, 1]
            v += [x0, y0, r, g, b, 1,  x2, y2, r, g, b, 1,  x3, y3, r, g, b, 1]
        }
    }

    private func buildWave(_ v: inout [Float], w: Float, h: Float) {
        let samples = min(waveform.count, 256)
        if samples < 2 { return }
        let step = w / Float(samples - 1)
        let midY = h / 2
        let thick: Float = 3.0
        let scale = h * 0.35

        for i in 0..<(samples - 1) {
            let v1 = waveform[i]
            let v2 = waveform[min(i + 1, samples - 1)]
            let x1 = Float(i) * step
            let x2 = Float(i + 1) * step
            let y1 = v1 * scale + midY
            let y2 = v2 * scale + midY
            let magI = max(0, min(127, i / 2))
            let mag = magI < magnitudes.count ? magnitudes[magI] : 0
            let (r, g, b) = hsvColor(i, mag, samples, 0.9, 0.95)

            // Wave line: filled thick line with glow-like triple-band
            for pass in 0..<3 {
                let alpha: Float = pass == 0 ? 1.0 : (pass == 1 ? 0.4 : 0.15)
                let offset: Float = pass == 0 ? 0 : thick * Float(pass) * 2.0
                let t = thick + offset
                v += [x1, y1 - t, r, g, b, alpha,
                      x2, y2 - t, r, g, b, alpha,
                      x2, y2 + t, r, g, b, alpha]
                v += [x1, y1 - t, r, g, b, alpha,
                      x2, y2 + t, r, g, b, alpha,
                      x1, y1 + t, r, g, b, alpha]
            }
        }
    }

    // MARK: - MTKViewDelegate

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let desc = view.currentRenderPassDescriptor,
              let buf = cmdQueue.makeCommandBuffer(),
              let enc = buf.makeRenderCommandEncoder(descriptor: desc) else { return }

        let size = view.drawableSize
        let verts = buildVertices(size: size)
        let vertCount = verts.count / 6

        if vertCount > 0 {
            let buffer = device.makeBuffer(
                bytes: verts,
                length: verts.count * MemoryLayout<Float>.size,
                options: .storageModeShared
            )!
            enc.setRenderPipelineState(pipeline)
            enc.setVertexBuffer(buffer, offset: 0, index: 0)
            var vp = simd_float2(Float(size.width), Float(size.height))
            enc.setVertexBytes(&vp, length: MemoryLayout<simd_float2>.size, index: 1)
            enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertCount)
        }

        enc.endEncoding()
        buf.present(view.currentDrawable!)
        buf.commit()
    }
}

// MARK: - Shader Source

private let shaderSource = """
#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    packed_float2 position;
    packed_float4 color;
};

struct VertexOut {
    float4 position [[position]];
    float4 color;
};

vertex VertexOut vertexShader(device const VertexIn *vertices [[buffer(0)]],
                              constant float2 &viewport [[buffer(1)]],
                              uint vid [[vertex_id]]) {
    float2 pos = vertices[vid].position;
    float2 clip = pos / viewport * 2.0 - 1.0;
    clip.y = -clip.y;
    VertexOut out;
    out.position = float4(clip, 0.0, 1.0);
    out.color = vertices[vid].color;
    return out;
}

fragment float4 fragmentShader(VertexOut in [[stage_in]]) {
    return in.color;
}
"""
