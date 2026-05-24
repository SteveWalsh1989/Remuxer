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
