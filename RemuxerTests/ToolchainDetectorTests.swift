import XCTest

@testable import Remuxer

final class ToolchainDetectorTests: XCTestCase {
  func testDetectsMissingFFmpegBeforeFFprobe() {
    let locator = ProcessToolLocator(
      bundledSearchDirectories: [
        URL(fileURLWithPath: "/definitely-missing")
      ],
      developerSearchDirectories: []
    )

    XCTAssertThrowsError(try locator.locateToolchain()) { error in
      XCTAssertEqual(error as? ToolchainError, .missingFFmpeg)
    }
  }

  func testFindsExecutablesInSearchDirectory() throws {
    let folderURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
    defer {
      try? FileManager.default.removeItem(at: folderURL)
    }

    let ffmpegURL = folderURL.appendingPathComponent("ffmpeg")
    let ffprobeURL = folderURL.appendingPathComponent("ffprobe")
    FileManager.default.createFile(atPath: ffmpegURL.path, contents: Data())
    FileManager.default.createFile(atPath: ffprobeURL.path, contents: Data())
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: ffmpegURL.path)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: ffprobeURL.path)

    let locator = ProcessToolLocator(
      bundledSearchDirectories: [folderURL],
      developerSearchDirectories: []
    )

    XCTAssertEqual(
      try locator.locateToolchain(),
      FFmpegToolchain(ffmpegURL: ffmpegURL, ffprobeURL: ffprobeURL)
    )
  }

  func testSearchesBundledRuntimeBeforeDeveloperRuntime() throws {
    let bundledFolderURL = try makeExecutableToolDirectory()
    let developerFolderURL = try makeExecutableToolDirectory()

    let locator = ProcessToolLocator(
      bundledSearchDirectories: [bundledFolderURL],
      developerSearchDirectories: [developerFolderURL]
    )

    XCTAssertEqual(
      try locator.locateToolchain(),
      FFmpegToolchain(
        ffmpegURL: bundledFolderURL.appendingPathComponent("ffmpeg"),
        ffprobeURL: bundledFolderURL.appendingPathComponent("ffprobe")
      )
    )
  }

  func testSearchesDeveloperRuntimeWhenBundledRuntimeIsMissing() throws {
    let developerFolderURL = try makeExecutableToolDirectory()

    let locator = ProcessToolLocator(
      bundledSearchDirectories: [],
      developerSearchDirectories: [developerFolderURL]
    )

    XCTAssertEqual(
      try locator.locateToolchain(),
      FFmpegToolchain(
        ffmpegURL: developerFolderURL.appendingPathComponent("ffmpeg"),
        ffprobeURL: developerFolderURL.appendingPathComponent("ffprobe")
      )
    )
  }

  private func makeExecutableToolDirectory() throws -> URL {
    let folderURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
    addTeardownBlock {
      try? FileManager.default.removeItem(at: folderURL)
    }

    let ffmpegURL = folderURL.appendingPathComponent("ffmpeg")
    let ffprobeURL = folderURL.appendingPathComponent("ffprobe")
    FileManager.default.createFile(atPath: ffmpegURL.path, contents: Data())
    FileManager.default.createFile(atPath: ffprobeURL.path, contents: Data())
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: ffmpegURL.path)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: ffprobeURL.path)

    return folderURL
  }
}
