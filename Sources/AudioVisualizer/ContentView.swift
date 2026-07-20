import SwiftUI

struct ContentView: View {
    @StateObject private var engine = AudioEngine()
    @State private var mode: VisMode = .bars
    @State private var task: Task<Void, Never>?

    var body: some View {
        ZStack {
            VisualizerView(
                magnitudes: engine.magnitudes,
                waveform: engine.waveform,
                mode: $mode
            )

            controlBar

            if !engine.isRunning && !engine.permissionDenied {
                loadingView
            }

            if engine.permissionDenied {
                noPermissionView
            }
        }
        .preferredColorScheme(.dark)
        .task { await start() }
        .onDisappear { task?.cancel(); engine.stop() }
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        VStack {
            Spacer()
            HStack(spacing: 16) {
                HStack(spacing: 10) {
                    levelMeter
                    Text("系统音频").font(.caption).foregroundColor(.white.opacity(0.7))
                }
                .padding(.leading, 8)

                Divider().frame(height: 24).background(.white.opacity(0.2))

                modeButton(.bars,  "chart.bar.fill",     "频谱")
                modeButton(.circle, "circle.dotted",      "环形")
                modeButton(.wave,   "waveform",           "波形")
            }
            .padding(10)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.1), lineWidth: 1))
            .padding(.bottom, 24)
        }
    }

    @ViewBuilder
    private var levelMeter: some View {
        let lv = engine.inputLevel
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.15)).frame(width: w)
                Capsule()
                    .fill(
                        LinearGradient(colors: [
                            .green, .yellow, .orange, .red
                        ], startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(width: w * CGFloat(lv))
            }
        }
        .frame(width: 48, height: 4)
    }

    // MARK: - Mode Button

    private func modeButton(_ m: VisMode, _ icon: String, _ label: String) -> some View {
        Button(action: { mode = m }) {
            VStack(spacing: 2) {
                Image(systemName: icon).font(.system(size: 13))
                Text(label).font(.system(size: 10))
            }
            .foregroundColor(mode == m ? .white : .white.opacity(0.45))
            .frame(minWidth: 44)
            .padding(.vertical, 6)
            .background(mode == m ? Color.white.opacity(0.12) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .keyboardShortcut(KeyEquivalent(Character(String(m.rawValue.first ?? "1"))), modifiers: .command)
    }

    // MARK: - Permission / Loading

    private var loadingView: some View {
        VStack(spacing: 10) {
            ProgressView().tint(.white)
            Text("获取音频权限...").font(.caption).foregroundColor(.secondary)
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var noPermissionView: some View {
        VStack(spacing: 10) {
            Image(systemName: "mic.slash.fill").font(.largeTitle).foregroundColor(.secondary)
            Text("需要麦克风权限").font(.headline).foregroundColor(.secondary)
            Text("系统设置 → 隐私 → 麦克风").font(.caption).foregroundColor(.secondary)
            Button("重试") { task = Task { await start() } }
                .buttonStyle(.borderedProminent).tint(.white.opacity(0.2)).controlSize(.small).padding(.top, 4)
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func start() async {
        engine.start()
    }
}
