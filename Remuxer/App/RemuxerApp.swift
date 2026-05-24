import SwiftUI

@main
struct RemuxerApp: App {
  @StateObject private var queue: ConversionQueue

  init() {
    let toolLocator = ProcessToolLocator()
    let planner = ConversionPlanner()
    let executor = FFmpegClient(toolLocator: toolLocator)
    let analyzer = FFprobeClient(toolLocator: toolLocator)

    _queue = StateObject(
      wrappedValue: ConversionQueue(
        analyzer: analyzer,
        planner: planner,
        executor: executor,
        toolLocator: toolLocator
      )
    )
  }

  var body: some Scene {
    WindowGroup {
      ContentView(queue: queue)
        .frame(minWidth: 1_080, minHeight: 680)
    }
    .commands {
      CommandGroup(replacing: .newItem) {}
      DeveloperModeCommands()
    }
  }
}

struct DeveloperModeCommands: Commands {
  @AppStorage("isDeveloperModeEnabled") private var isDeveloperModeEnabled = false

  var body: some Commands {
    CommandGroup(after: .toolbar) {
      Toggle("Developer Mode", isOn: $isDeveloperModeEnabled)
    }
  }
}
