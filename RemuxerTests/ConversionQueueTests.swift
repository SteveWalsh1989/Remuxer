import XCTest

@testable import Remuxer

@MainActor
final class ConversionQueueTests: XCTestCase {
  func testAnalyzeTransitionsQueuedItemToReady() async {
    let resourceAccess = FakeResourceAccess()
    let queue = makeQueue(resourceAccess: resourceAccess)

    queue.addFiles([URL(fileURLWithPath: "/Movies/Movie.mkv")])
    await queue.analyzeItems()

    XCTAssertEqual(queue.items.first?.status, .ready)
    XCTAssertNotNil(queue.items.first?.plan)
    XCTAssertEqual(resourceAccess.accessedURLs.first, [URL(fileURLWithPath: "/Movies/Movie.mkv")])
  }

  func testAnalyzeMarksItemFailedWhenToolchainIsMissing() async {
    let queue = makeQueue(toolLocator: FakeToolLocator(result: .failure(.missingFFmpeg)))

    queue.addFiles([URL(fileURLWithPath: "/Movies/Movie.mkv")])
    await queue.analyzeItems()

    XCTAssertEqual(queue.toolchainErrorMessage, ToolchainError.missingFFmpeg.localizedDescription)
    XCTAssertEqual(
      queue.items.first?.status, .failed(ToolchainError.missingFFmpeg.localizedDescription))
  }

  func testConversionRunsSubtitleAndPrimaryCommands() async {
    let executor = FakeExecutor()
    let outputPreparer = FakeOutputPreparer()
    let resourceAccess = FakeResourceAccess()
    let queue = makeQueue(
      executor: executor,
      outputPreparer: outputPreparer,
      resourceAccess: resourceAccess
    )

    queue.addFiles([URL(fileURLWithPath: "/Movies/Movie.mkv")])
    await queue.startConversion()

    XCTAssertEqual(queue.items.first?.status, .completed)
    XCTAssertEqual(outputPreparer.outputs.first?.videoURL.lastPathComponent, "Movie.mp4")
    let accessedPathSets = resourceAccess.accessedURLs.map {
      Set($0.map(\.standardizedFileURL.path))
    }
    XCTAssertTrue(
      accessedPathSets.contains { paths in
        paths.contains("/Movies/Movie.mkv") && paths.contains("/Movies")
      }
    )
    XCTAssertEqual(executor.commands.count, 2)
  }

  func testConversionDoesNotRunCommandsWhenOutputPreparationFails() async {
    let executor = FakeExecutor()
    let outputPreparer = FakeOutputPreparer(result: .failure(FakeOutputPrepareError.failed))
    let queue = makeQueue(executor: executor, outputPreparer: outputPreparer)

    queue.addFiles([URL(fileURLWithPath: "/Movies/Movie.mkv")])
    await queue.startConversion()

    XCTAssertEqual(queue.items.first?.status, .failed("Could not create output folder."))
    XCTAssertEqual(executor.commands.count, 0)
  }

  func testDestinationSelectionPersistsRecentAndSavedLocations() {
    let destinationStore = FakeDestinationStore()
    let queue = makeQueue(destinationStore: destinationStore)
    let exportsURL = URL(fileURLWithPath: "/Exports")

    queue.chooseDestinationFolder(exportsURL)
    queue.saveSelectedDestination()

    XCTAssertEqual(queue.recentDestinationURLs, [exportsURL])
    XCTAssertEqual(queue.savedDestinationURLs, [exportsURL])
    XCTAssertEqual(destinationStore.savedRecentDestinations, [exportsURL])
    XCTAssertEqual(destinationStore.savedPinnedDestinations, [exportsURL])
  }

  func testCustomOutputNameReplansAnalyzedItem() async throws {
    let queue = makeQueue()

    queue.addFiles([URL(fileURLWithPath: "/Movies/Movie.mkv")])
    await queue.analyzeItems()
    let itemID = try XCTUnwrap(queue.items.first?.id)

    queue.setCustomOutputName("Movie Export", for: itemID)

    XCTAssertEqual(queue.items.first?.plan?.output.videoURL.lastPathComponent, "Movie Export.mp4")
  }

  private func makeQueue(
    executor: FakeExecutor? = nil,
    toolLocator: FakeToolLocator = FakeToolLocator(),
    destinationStore: DestinationPersisting = FakeDestinationStore(),
    outputPreparer: OutputPreparing = FakeOutputPreparer(),
    resourceAccess: SecurityScopedResourceAccessing = FakeResourceAccess()
  ) -> ConversionQueue {
    let executor = executor ?? FakeExecutor()

    return ConversionQueue(
      analyzer: FakeAnalyzer(),
      planner: ConversionPlanner(
        outputPathResolver: OutputPathResolver(fileChecker: EmptyFileChecker())),
      executor: executor,
      toolLocator: toolLocator,
      destinationStore: destinationStore,
      outputPreparer: outputPreparer,
      resourceAccess: resourceAccess
    )
  }
}

private struct FakeAnalyzer: MediaAnalyzing {
  func analyze(url: URL) async throws -> ProbedMediaFile {
    ProbedMediaFile(
      sourceURL: url,
      formatName: "matroska",
      duration: 100,
      streams: [
        MediaStream(
          index: 0,
          kind: .video,
          codecName: "h264",
          codecLongName: nil,
          language: nil,
          title: nil,
          width: 1920,
          height: 1080,
          channelCount: nil
        ),
        MediaStream(
          index: 1,
          kind: .audio,
          codecName: "aac",
          codecLongName: nil,
          language: nil,
          title: nil,
          width: nil,
          height: nil,
          channelCount: 2
        ),
        MediaStream(
          index: 2,
          kind: .subtitle,
          codecName: "subrip",
          codecLongName: nil,
          language: "eng",
          title: nil,
          width: nil,
          height: nil,
          channelCount: nil
        ),
      ],
      chapters: [],
      metadata: [:]
    )
  }
}

@MainActor
private final class FakeExecutor: ConversionExecuting {
  private(set) var commands: [ProcessCommand] = []

  func run(
    _ command: ProcessCommand,
    duration: TimeInterval?,
    progress: @escaping @Sendable (Double) -> Void,
    log: @escaping @Sendable (String) -> Void
  ) async throws {
    commands.append(command)
    progress(1)
    log(command.displayString)
  }

  func cancel() {}
}

private struct FakeToolLocator: ToolLocating {
  var result: Result<FFmpegToolchain, ToolchainError> = .success(
    FFmpegToolchain(
      ffmpegURL: URL(fileURLWithPath: "/usr/local/bin/ffmpeg"),
      ffprobeURL: URL(fileURLWithPath: "/usr/local/bin/ffprobe")
    )
  )

  func locateToolchain() throws -> FFmpegToolchain {
    try result.get()
  }
}

private final class FakeDestinationStore: DestinationPersisting {
  private(set) var savedRecentDestinations: [URL] = []
  private(set) var savedPinnedDestinations: [URL] = []

  func loadRecentDestinations() -> [URL] {
    savedRecentDestinations
  }

  func loadSavedDestinations() -> [URL] {
    savedPinnedDestinations
  }

  func saveRecentDestinations(_ urls: [URL]) {
    savedRecentDestinations = urls
  }

  func saveSavedDestinations(_ urls: [URL]) {
    savedPinnedDestinations = urls
  }
}

private enum FakeOutputPrepareError: LocalizedError {
  case failed

  var errorDescription: String? {
    "Could not create output folder."
  }
}

private final class FakeOutputPreparer: OutputPreparing {
  private(set) var outputs: [PlannedOutput] = []
  let result: Result<Void, Error>

  init(result: Result<Void, Error> = .success(())) {
    self.result = result
  }

  func prepareOutput(for output: PlannedOutput) throws {
    outputs.append(output)
    try result.get()
  }
}

private final class FakeResourceAccess: SecurityScopedResourceAccessing {
  private(set) var accessedURLs: [[URL]] = []

  func access<T>(
    urls: [URL],
    operation: () async throws -> T
  ) async throws -> T {
    accessedURLs.append(urls)
    return try await operation()
  }
}
