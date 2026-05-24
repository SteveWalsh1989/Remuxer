import XCTest

@testable import Remuxer

@MainActor
final class FFmpegClientTests: XCTestCase {
  func testRunsDetectedFFmpegExecutableForFFmpegCommand() async throws {
    let runner = FakeProcessRunner()
    let client = FFmpegClient(
      toolLocator: StubToolLocator(),
      processRunner: runner
    )

    try await client.run(
      ProcessCommand(executableName: "ffmpeg", arguments: ["-version"]),
      duration: nil,
      progress: { _ in },
      log: { _ in }
    )

    XCTAssertEqual(runner.requests.first?.executableURL.path, "/Tools/ffmpeg")
    XCTAssertEqual(runner.requests.first?.arguments, ["-version"])
  }

  func testRunsDetectedFFprobeExecutableForFFprobeCommand() async throws {
    let runner = FakeProcessRunner()
    let client = FFmpegClient(
      toolLocator: StubToolLocator(),
      processRunner: runner
    )

    try await client.run(
      ProcessCommand(executableName: "ffprobe", arguments: ["-version"]),
      duration: nil,
      progress: { _ in },
      log: { _ in }
    )

    XCTAssertEqual(runner.requests.first?.executableURL.path, "/Tools/ffprobe")
  }

  func testCancelDelegatesToProcessRunner() {
    let runner = FakeProcessRunner()
    let client = FFmpegClient(
      toolLocator: StubToolLocator(),
      processRunner: runner
    )

    client.cancel()

    XCTAssertTrue(runner.didCancel)
  }
}

private struct StubToolLocator: ToolLocating {
  func locateToolchain() throws -> FFmpegToolchain {
    FFmpegToolchain(
      ffmpegURL: URL(fileURLWithPath: "/Tools/ffmpeg"),
      ffprobeURL: URL(fileURLWithPath: "/Tools/ffprobe")
    )
  }
}

@MainActor
private final class FakeProcessRunner: ExternalProcessRunning {
  struct Request {
    let executableURL: URL
    let arguments: [String]
  }

  private(set) var requests: [Request] = []
  private(set) var didCancel = false

  func run(
    executableURL: URL,
    arguments: [String],
    duration: TimeInterval?,
    progress: @escaping @Sendable (Double) -> Void,
    log: @escaping @Sendable (String) -> Void
  ) async throws {
    requests.append(Request(executableURL: executableURL, arguments: arguments))
    progress(1)
  }

  func cancel() {
    didCancel = true
  }
}
