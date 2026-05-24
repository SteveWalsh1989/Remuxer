import XCTest

@testable import Remuxer

final class ToolchainDetectorTests: XCTestCase {
  func testDetectsMissingFFmpegBeforeFFprobe() {
    let locator = ProcessToolLocator(searchDirectories: [
      URL(fileURLWithPath: "/definitely-missing")
    ])

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

    let locator = ProcessToolLocator(searchDirectories: [folderURL])

    XCTAssertEqual(
      try locator.locateToolchain(),
      FFmpegToolchain(ffmpegURL: ffmpegURL, ffprobeURL: ffprobeURL)
    )
  }
}
