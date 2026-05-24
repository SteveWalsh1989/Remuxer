import XCTest

@testable import Remuxer

final class OutputPathResolverTests: XCTestCase {
  func testChangesExtensionBesideSourceByDefault() throws {
    let resolver = OutputPathResolver(fileChecker: EmptyFileChecker())
    let output = try resolver.videoOutputURL(
      for: URL(fileURLWithPath: "/Movies/john-wick.mkv"),
      preset: .losslessMP4,
      options: OutputOptions()
    )

    XCTAssertEqual(output.path, "/Movies/john-wick.mp4")
  }

  func testUsesSelectedFolder() throws {
    let resolver = OutputPathResolver(fileChecker: EmptyFileChecker())
    var options = OutputOptions()
    options.locationMode = .selectedFolder
    options.selectedFolderURL = URL(fileURLWithPath: "/Exports")

    let output = try resolver.videoOutputURL(
      for: URL(fileURLWithPath: "/Movies/john-wick.mkv"),
      preset: .losslessMP4,
      options: options
    )

    XCTAssertEqual(output.path, "/Exports/john-wick.mp4")
  }

  func testUsesCustomOutputName() throws {
    let resolver = OutputPathResolver(fileChecker: EmptyFileChecker())

    let output = try resolver.videoOutputURL(
      for: URL(fileURLWithPath: "/Movies/john-wick.mkv"),
      preset: .losslessMP4,
      options: OutputOptions(),
      customOutputName: "john-wick-remastered"
    )

    XCTAssertEqual(output.path, "/Movies/john-wick-remastered.mp4")
  }

  func testStripsMatchingExtensionFromCustomOutputName() throws {
    let resolver = OutputPathResolver(fileChecker: EmptyFileChecker())

    let output = try resolver.videoOutputURL(
      for: URL(fileURLWithPath: "/Movies/john-wick.mkv"),
      preset: .losslessMP4,
      options: OutputOptions(),
      customOutputName: "john-wick-remastered.mp4"
    )

    XCTAssertEqual(output.path, "/Movies/john-wick-remastered.mp4")
  }

  func testRejectsCustomOutputNameWithPathSeparator() {
    let resolver = OutputPathResolver(fileChecker: EmptyFileChecker())

    XCTAssertThrowsError(
      try resolver.videoOutputURL(
        for: URL(fileURLWithPath: "/Movies/john-wick.mkv"),
        preset: .losslessMP4,
        options: OutputOptions(),
        customOutputName: "Action/john-wick"
      )
    )
  }

  func testCreatesFolderPerSource() throws {
    let resolver = OutputPathResolver(fileChecker: EmptyFileChecker())
    var options = OutputOptions()
    options.locationMode = .perSourceFolder
    options.selectedFolderURL = URL(fileURLWithPath: "/Exports")

    let output = try resolver.videoOutputURL(
      for: URL(fileURLWithPath: "/Movies/john-wick.mkv"),
      preset: .losslessMP4,
      options: options
    )

    XCTAssertEqual(output.path, "/Exports/john-wick/john-wick.mp4")
  }

  func testUsesCustomOutputNameForSidecars() throws {
    let resolver = OutputPathResolver(fileChecker: EmptyFileChecker())
    let stream = MediaStream(
      index: 3,
      kind: .subtitle,
      codecName: "subrip",
      codecLongName: nil,
      language: "eng",
      title: nil,
      width: nil,
      height: nil,
      channelCount: nil
    )

    let output = try resolver.sidecarURL(
      for: URL(fileURLWithPath: "/Movies/john-wick.mkv"),
      stream: stream,
      extension: "srt",
      options: OutputOptions(),
      customOutputName: "john-wick-remastered.mp4",
      videoOutputExtension: "mp4"
    )

    XCTAssertEqual(output.path, "/Movies/john-wick-remastered.3.eng.srt")
  }

  func testOutputNameSequenceUsesStartWidthAsPadding() throws {
    let sequence = try OutputNameSequence(prefix: "PeaceMaker S02E", startNumberText: "01")

    XCTAssertEqual(
      sequence.names(count: 3),
      ["PeaceMaker S02E01", "PeaceMaker S02E02", "PeaceMaker S02E03"]
    )
  }

  func testOutputNameSequencePreservesThreeDigitPadding() throws {
    let sequence = try OutputNameSequence(prefix: "Scene ", startNumberText: "001")

    XCTAssertEqual(sequence.names(count: 3), ["Scene 001", "Scene 002", "Scene 003"])
  }

  func testOutputNameSequenceAllowsCounterToGrowPastInitialWidth() throws {
    let sequence = try OutputNameSequence(prefix: "Episode ", startNumberText: "99")

    XCTAssertEqual(sequence.names(count: 3), ["Episode 99", "Episode 100", "Episode 101"])
  }

  func testOutputNameSequenceRejectsInvalidStartNumber() {
    XCTAssertThrowsError(
      try OutputNameSequence(prefix: "Movie ", startNumberText: "")
    ) { error in
      XCTAssertEqual(error as? OutputNameSequenceError, .invalidStartNumber)
    }

    XCTAssertThrowsError(
      try OutputNameSequence(prefix: "Movie ", startNumberText: "A1")
    ) { error in
      XCTAssertEqual(error as? OutputNameSequenceError, .invalidStartNumber)
    }
  }

  func testAutoRenamesCollidingOutput() throws {
    let resolver = OutputPathResolver(
      fileChecker: StubFileChecker(existingPaths: ["/Movies/john-wick.mp4"])
    )

    let output = try resolver.videoOutputURL(
      for: URL(fileURLWithPath: "/Movies/john-wick.mkv"),
      preset: .losslessMP4,
      options: OutputOptions()
    )

    XCTAssertEqual(output.path, "/Movies/john-wick 2.mp4")
  }

  func testAutoRenamesMP4SourceWhenRepairingBesideSource() throws {
    let resolver = OutputPathResolver(
      fileChecker: StubFileChecker(existingPaths: ["/Movies/john-wick.mp4"])
    )

    let output = try resolver.videoOutputURL(
      for: URL(fileURLWithPath: "/Movies/john-wick.mp4"),
      preset: .losslessMP4,
      options: OutputOptions()
    )

    XCTAssertEqual(output.path, "/Movies/john-wick 2.mp4")
  }

  func testBlocksCollidingOutputWhenConfigured() {
    let resolver = OutputPathResolver(
      fileChecker: StubFileChecker(existingPaths: ["/Movies/john-wick.mp4"])
    )
    var options = OutputOptions()
    options.collisionResolution = .block

    XCTAssertThrowsError(
      try resolver.videoOutputURL(
        for: URL(fileURLWithPath: "/Movies/john-wick.mkv"),
        preset: .losslessMP4,
        options: options
      )
    )
  }
}

struct EmptyFileChecker: FileExistenceChecking {
  func fileExists(atPath path: String) -> Bool {
    false
  }
}

struct StubFileChecker: FileExistenceChecking {
  let existingPaths: Set<String>

  func fileExists(atPath path: String) -> Bool {
    existingPaths.contains(path)
  }
}
