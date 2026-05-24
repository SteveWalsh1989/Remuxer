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

  func testConversionRemovesSourceAfterSuccessfulConversionWhenEnabled() async {
    let sourceFileCleaner = FakeSourceFileCleaner()
    let queue = makeQueue(sourceFileCleaner: sourceFileCleaner)
    let sourceURL = URL(fileURLWithPath: "/Movies/Movie.mkv")
    queue.outputOptions.removeSourceAfterSuccess = true

    queue.addFiles([sourceURL])
    await queue.startConversion()

    XCTAssertEqual(queue.items.first?.status, .completed)
    XCTAssertEqual(sourceFileCleaner.removedURLs, [sourceURL])
    XCTAssertTrue(queue.items.first?.logLines.contains("Removed original file") == true)
  }

  func testConversionDoesNotRunCommandsWhenOutputPreparationFails() async {
    let executor = FakeExecutor()
    let outputPreparer = FakeOutputPreparer(result: .failure(FakeOutputPrepareError.failed))
    let sourceFileCleaner = FakeSourceFileCleaner()
    let queue = makeQueue(
      executor: executor,
      outputPreparer: outputPreparer,
      sourceFileCleaner: sourceFileCleaner
    )
    queue.outputOptions.removeSourceAfterSuccess = true

    queue.addFiles([URL(fileURLWithPath: "/Movies/Movie.mkv")])
    await queue.startConversion()

    XCTAssertEqual(queue.items.first?.status, .failed("Could not create output folder."))
    XCTAssertEqual(executor.commands.count, 0)
    XCTAssertTrue(sourceFileCleaner.removedURLs.isEmpty)
  }

  func testSourceRemovalFailureMarksCompletedConversionAsFailed() async {
    let sourceFileCleaner = FakeSourceFileCleaner(result: .failure(FakeSourceDeleteError.denied))
    let queue = makeQueue(sourceFileCleaner: sourceFileCleaner)
    queue.outputOptions.removeSourceAfterSuccess = true

    queue.addFiles([URL(fileURLWithPath: "/Movies/Movie.mkv")])
    await queue.startConversion()

    guard case .failed(let message) = queue.items.first?.status else {
      return XCTFail("Expected failed cleanup status.")
    }

    XCTAssertTrue(message.contains("could not remove the original file"))
    XCTAssertEqual(sourceFileCleaner.removedURLs, [URL(fileURLWithPath: "/Movies/Movie.mkv")])
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

  func testOutputNameSequenceAppliesToFullQueueWhenSelectionIsEmpty() throws {
    let queue = makeQueue()

    queue.addFiles([
      URL(fileURLWithPath: "/Shows/Episode A.mkv"),
      URL(fileURLWithPath: "/Shows/Episode B.mkv"),
      URL(fileURLWithPath: "/Shows/Episode C.mkv"),
    ])

    try queue.applyOutputNameSequence(
      prefix: "PeaceMaker S02E",
      startNumberText: "01",
      to: []
    )

    XCTAssertEqual(
      queue.items.map(\.customOutputName),
      ["PeaceMaker S02E01", "PeaceMaker S02E02", "PeaceMaker S02E03"]
    )
  }

  func testOutputNameSequenceAppliesOnlyToSelectionInQueueOrder() throws {
    let queue = makeQueue()

    queue.addFiles([
      URL(fileURLWithPath: "/Shows/Episode A.mkv"),
      URL(fileURLWithPath: "/Shows/Episode B.mkv"),
      URL(fileURLWithPath: "/Shows/Episode C.mkv"),
    ])
    let selectedIDs: Set<QueueItem.ID> = [queue.items[2].id, queue.items[0].id]

    try queue.applyOutputNameSequence(
      prefix: "PeaceMaker S02E",
      startNumberText: "01",
      to: selectedIDs
    )

    XCTAssertEqual(
      queue.items.map(\.customOutputName),
      ["PeaceMaker S02E01", "", "PeaceMaker S02E02"]
    )
  }

  func testOutputNameSequenceOverwritesExistingCustomNamesOnTargets() throws {
    let queue = makeQueue()

    queue.addFiles([
      URL(fileURLWithPath: "/Shows/Episode A.mkv"),
      URL(fileURLWithPath: "/Shows/Episode B.mkv"),
    ])
    try queue.applyOutputNameSequence(prefix: "Old ", startNumberText: "01", to: [])
    try queue.applyOutputNameSequence(prefix: "New ", startNumberText: "07", to: [])

    XCTAssertEqual(queue.items.map(\.customOutputName), ["New 07", "New 08"])
  }

  func testOutputNameSequenceReplansAnalyzedItems() async throws {
    let queue = makeQueue()

    queue.addFiles([URL(fileURLWithPath: "/Shows/Episode A.mkv")])
    await queue.analyzeItems()
    let itemID = try XCTUnwrap(queue.items.first?.id)

    try queue.applyOutputNameSequence(
      prefix: "PeaceMaker S02E",
      startNumberText: "01",
      to: [itemID]
    )

    XCTAssertEqual(
      queue.items.first?.plan?.output.videoURL.lastPathComponent,
      "PeaceMaker S02E01.mp4"
    )
    XCTAssertEqual(
      queue.items.first?.plan?.output.sidecarURLs.first?.lastPathComponent,
      "PeaceMaker S02E01.2.eng.srt"
    )
  }

  func testRefreshToolchainStatusReportsMissingBundledRuntime() {
    let toolLocator = FakeToolLocator(result: .failure(.missingFFmpeg))
    let queue = makeQueue(toolLocator: toolLocator)

    queue.refreshToolchainStatus()

    XCTAssertEqual(queue.toolchainErrorMessage, ToolchainError.missingFFmpeg.localizedDescription)
  }

  private func makeQueue(
    executor: FakeExecutor? = nil,
    toolLocator: FakeToolLocator = FakeToolLocator(),
    destinationStore: DestinationPersisting = FakeDestinationStore(),
    outputPreparer: OutputPreparing = FakeOutputPreparer(),
    resourceAccess: SecurityScopedResourceAccessing = FakeResourceAccess(),
    sourceFileCleaner: SourceFileCleaning = FakeSourceFileCleaner()
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
      resourceAccess: resourceAccess,
      sourceFileCleaner: sourceFileCleaner
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

private final class FakeToolLocator: ToolLocating {
  var result: Result<FFmpegToolchain, ToolchainError> = .success(
    FFmpegToolchain(
      ffmpegURL: URL(fileURLWithPath: "/Remuxer.app/Contents/Resources/FFmpeg/bin/ffmpeg"),
      ffprobeURL: URL(fileURLWithPath: "/Remuxer.app/Contents/Resources/FFmpeg/bin/ffprobe")
    )
  )

  init(
    result: Result<FFmpegToolchain, ToolchainError> = .success(
      FFmpegToolchain(
        ffmpegURL: URL(fileURLWithPath: "/Remuxer.app/Contents/Resources/FFmpeg/bin/ffmpeg"),
        ffprobeURL: URL(fileURLWithPath: "/Remuxer.app/Contents/Resources/FFmpeg/bin/ffprobe")
      )
    )
  ) {
    self.result = result
  }

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

private enum FakeSourceDeleteError: LocalizedError {
  case denied

  var errorDescription: String? {
    "Source could not be removed."
  }
}

private final class FakeSourceFileCleaner: SourceFileCleaning {
  private(set) var removedURLs: [URL] = []
  let result: Result<Void, Error>

  init(result: Result<Void, Error> = .success(())) {
    self.result = result
  }

  func removeSourceFile(at url: URL) throws {
    removedURLs.append(url)
    do {
      try result.get()
    } catch {
      throw SourceFileDeletionError.removeFailed(url, error.localizedDescription)
    }
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
