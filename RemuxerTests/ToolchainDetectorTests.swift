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

  func testSearchesBundledRuntimeBeforeConfiguredAndDefaultDirectories() throws {
    let bundledFolderURL = try makeExecutableToolDirectory()
    let configuredFolderURL = try makeExecutableToolDirectory()
    let fallbackFolderURL = try makeExecutableToolDirectory()
    let configurationStore = FakeToolchainConfigurationStore(
      configuredDirectoryURL: configuredFolderURL)

    let locator = ProcessToolLocator(
      searchDirectories: [fallbackFolderURL],
      bundledSearchDirectories: [bundledFolderURL],
      configurationStore: configurationStore
    )

    XCTAssertEqual(
      try locator.locateToolchain(),
      FFmpegToolchain(
        ffmpegURL: bundledFolderURL.appendingPathComponent("ffmpeg"),
        ffprobeURL: bundledFolderURL.appendingPathComponent("ffprobe")
      )
    )
  }

  func testSearchesConfiguredDirectoryBeforeDefaultDirectories() throws {
    let configuredFolderURL = try makeExecutableToolDirectory()
    let fallbackFolderURL = try makeExecutableToolDirectory()
    let configurationStore = FakeToolchainConfigurationStore(
      configuredDirectoryURL: configuredFolderURL)

    let locator = ProcessToolLocator(
      searchDirectories: [fallbackFolderURL],
      bundledSearchDirectories: [],
      configurationStore: configurationStore
    )

    XCTAssertEqual(
      try locator.locateToolchain(),
      FFmpegToolchain(
        ffmpegURL: configuredFolderURL.appendingPathComponent("ffmpeg"),
        ffprobeURL: configuredFolderURL.appendingPathComponent("ffprobe")
      )
    )
  }

  func testPersistsConfiguredDirectory() {
    let configurationStore = FakeToolchainConfigurationStore()
    let locator = ProcessToolLocator(configurationStore: configurationStore)
    let folderURL = URL(fileURLWithPath: "/Tools/ffmpeg")

    locator.setConfiguredDirectoryURL(folderURL)

    XCTAssertEqual(locator.configuredDirectoryURL, folderURL)

    locator.setConfiguredDirectoryURL(nil)

    XCTAssertNil(locator.configuredDirectoryURL)
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

private final class FakeToolchainConfigurationStore: ToolchainConfigurationPersisting {
  private var configuredDirectoryURL: URL?

  init(configuredDirectoryURL: URL? = nil) {
    self.configuredDirectoryURL = configuredDirectoryURL
  }

  func loadConfiguredDirectoryURL() -> URL? {
    configuredDirectoryURL
  }

  func saveConfiguredDirectoryURL(_ url: URL?) {
    configuredDirectoryURL = url
  }
}
