import Foundation

struct FFmpegToolchain: Equatable {
  let ffmpegURL: URL
  let ffprobeURL: URL
}

protocol ToolLocating {
  func locateToolchain() throws -> FFmpegToolchain
}

enum ToolchainError: LocalizedError, Equatable {
  case missingFFmpeg
  case missingFFprobe

  var errorDescription: String? {
    switch self {
    case .missingFFmpeg:
      "FFmpeg was not found. Install it with Homebrew or configure it before converting."
    case .missingFFprobe:
      "ffprobe was not found. Install FFmpeg with Homebrew so media files can be analyzed."
    }
  }
}

struct ProcessToolLocator: ToolLocating {
  var searchDirectories: [URL] = [
    URL(fileURLWithPath: "/opt/homebrew/bin"),
    URL(fileURLWithPath: "/usr/local/bin"),
    URL(fileURLWithPath: "/usr/bin"),
  ]

  func locateToolchain() throws -> FFmpegToolchain {
    guard let ffmpegURL = locateExecutable(named: "ffmpeg") else {
      throw ToolchainError.missingFFmpeg
    }

    guard let ffprobeURL = locateExecutable(named: "ffprobe") else {
      throw ToolchainError.missingFFprobe
    }

    return FFmpegToolchain(ffmpegURL: ffmpegURL, ffprobeURL: ffprobeURL)
  }

  private func locateExecutable(named executableName: String) -> URL? {
    searchDirectories
      .map { $0.appendingPathComponent(executableName) }
      .first { FileManager.default.isExecutableFile(atPath: $0.path) }
  }
}
