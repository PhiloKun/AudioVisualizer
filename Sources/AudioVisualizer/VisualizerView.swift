import SwiftUI
import MetalKit

struct VisualizerView: NSViewRepresentable {
    let magnitudes: [Float]
    let waveform: [Float]
    @Binding var mode: VisMode

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> MTKView {
        let mtk = MTKView()
        mtk.autoresizingMask = [.width, .height]
        context.coordinator.renderer = MetalRenderer(view: mtk)
        return mtk
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        let renderer = context.coordinator.renderer
        renderer?.magnitudes = magnitudes
        renderer?.waveform = waveform
        renderer?.mode = mode
        nsView.draw()
    }

    class Coordinator {
        var renderer: MetalRenderer?
    }
}
