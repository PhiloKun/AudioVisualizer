# Audio Visualizer 🎵

macOS real-time audio visualization app built with SwiftUI + Metal.

A macOS real-time audio visualization tool. Captures microphone input, performs FFT analysis, and renders dynamic visualizations using Metal shaders with 3 display modes.

---

## 功能 Features

- **实时频谱** Real-time FFT spectrum — 128-band log-spaced frequency visualization
- **三种可视化模式** 3 Visualization Modes — Spectrum Bars / Circular / Waveform
- **HSV 动态配色** HSV dynamic color — frequency-index-based rainbow cycling with magnitude modulation
- **电平指示** Input level meter — green → yellow → orange → red gradient
- **玻璃态控制栏** Glass-morphism control bar — thin material background with mode switches
- **键盘快捷键** Keyboard shortcuts — `⌘B` / `⌘C` / `⌘W` switch modes instantly

## 技术栈 Tech Stack

| Layer | Technology |
|-------|-----------|
| Language | Swift 5.9 |
| UI | SwiftUI |
| Graphics | Metal (custom vertex + fragment shaders) |
| Audio | AVFoundation / AVAudioEngine (microphone input) |
| DSP | Accelerate (vDSP FFT, Hann window, log-spaced band mapping) |

## 系统要求 Requirements

- macOS 14.0+ (Sonoma)
- Microphone access (for audio input)
- Xcode 15+ or Swift 5.9+

## 安装 Build & Run

```bash
git clone https://github.com/PhiloKun/AudioVisualizer.git
cd AudioVisualizer
swift run
```

Or open in Xcode:

```bash
open Package.swift
```

## 使用 Usage

1. Launch app — microphone permission prompt appears
2. Grant microphone access
3. Play music or make sound near your mic
4. Switch modes via bottom control bar or keyboard shortcuts:
   - `⌘B` — Bars mode (spectrum bars)
   - `⌘C` — Circle mode (radial spectrum)
   - `⌘W` — Wave mode (oscilloscope waveform)

## 项目结构 Structure

```
AudioVisualizer
├── Package.swift
├── Sources/
│   └── AudioVisualizer/
│       ├── AudioVisualizerApp.swift    # App entry point
│       ├── ContentView.swift           # Main UI + control bar
│       ├── AudioEngine.swift           # Audio capture + FFT pipeline
│       ├── VisualizerView.swift         # MTKView NSViewRepresentable
│       └── MetalRenderer.swift          # Metal vertex generation + shaders
```

## 路线图 Roadmap

- [x] Microphone input + FFT analysis
- [x] 3 visualization modes (bars / circle / wave)
- [x] HSV dynamic coloring
- [x] Glass-morphism control bar
- [ ] System audio capture (requires code signing)
- [ ] Audio file playback
- [ ] Custom color themes
- [ ] Window resize responsiveness improvements

## 许可 License

MIT
