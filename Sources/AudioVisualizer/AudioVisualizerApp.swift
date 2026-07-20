import SwiftUI

@main
struct AudioVisualizerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 600, minHeight: 400)
        }
        .windowResizability(.contentMinSize)
    }
}
