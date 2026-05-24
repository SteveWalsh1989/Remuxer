import Foundation

struct FFmpegToolchain: Equatable {
  let ffmpegURL: URL
  let ffprobeURL: URL
}

protocol ToolLocating {
  func locateToolchain() throws -> FFmpegToolchain
}

protocol ToolchainManaging: ToolLocating {
  var configuredDirectoryURL: URL? { get }

  func setConfiguredDirectoryURL(_ url: URL?)
}

protocol ToolchainConfigurationPersisting {
  func loadConfiguredDirectoryURL() -> URL?
  func saveConfiguredDirectoryURL(_ url: URL?)
}

struct UserDefaultsToolchainConfigurationStore: ToolchainConfigurationPersisting {
  private enum Key {
    static let configuredDirectoryPath = "configuredToolchainDirectoryPath"
  }

  var userDefaults: UserDefaults = .standard

  func loadConfiguredDirectoryURL() -> URL? {
    guard let path = userDefaults.string(forKey: Key.configuredDirectoryPath),
      path.isEmpty == false
    else {
      return nil
    }

    return URL(fileURLWithPath: path)
  }

  func saveConfiguredDirectoryURL(_ url: URL?) {
    guard let url else {
      userDefaults.removeObject(forKey: Key.configuredDirectoryPath)
      return
    }

    userDefaults.set(url.path, forKey: Key.configuredDirectoryPath)
  }
}

enum ToolchainError: LocalizedError, Equatable {
  case missingFFmpeg
  case missingFFprobe

  var errorDescription: String? {
    switch self {
    case .missingFFmpeg:
      [
        "FFmpeg was not found.",
        "Install it with Homebrew using `brew install ffmpeg`,",
        "or choose the folder that contains ffmpeg and ffprobe.",
      ].joined(separator: " ")
    case .missingFFprobe:
      [
        "ffprobe was not found.",
        "Install FFmpeg with Homebrew using `brew install ffmpeg`,",
        "or choose the folder that contains ffmpeg and ffprobe.",
      ].joined(separator: " ")
    }
  }
}

struct ProcessToolLocator: ToolchainManaging {
  static let defaultSearchDirectories: [URL] = [
    URL(fileURLWithPath: "/opt/homebrew/bin"),
    URL(fileURLWithPath: "/usr/local/bin"),
    URL(fileURLWithPath: "/usr/bin"),
  ]

  var searchDirectories: [URL]
  private let configurationStore: ToolchainConfigurationPersisting

  init(
    searchDirectories: [URL] = Self.defaultSearchDirectories,
    configurationStore: ToolchainConfigurationPersisting = UserDefaultsToolchainConfigurationStore()
  ) {
    self.searchDirectories = searchDirectories
    self.configurationStore = configurationStore
  }

  var configuredDirectoryURL: URL? {
    configurationStore.loadConfiguredDirectoryURL()
  }

  func setConfiguredDirectoryURL(_ url: URL?) {
    configurationStore.saveConfiguredDirectoryURL(url)
  }

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
    effectiveSearchDirectories
      .map { $0.appendingPathComponent(executableName) }
      .first { FileManager.default.isExecutableFile(atPath: $0.path) }
  }

  private var effectiveSearchDirectories: [URL] {
    var directories = searchDirectories

    if let configuredDirectoryURL {
      directories.insert(configuredDirectoryURL, at: 0)
    }

    return directories.uniquedByStandardizedFileURL()
  }
}

extension Array where Element == URL {
  fileprivate func uniquedByStandardizedFileURL() -> [URL] {
    var seenURLs = Set<URL>()
    var result: [URL] = []

    for url in self {
      let standardizedURL = url.standardizedFileURL
      guard seenURLs.contains(standardizedURL) == false else {
        continue
      }

      seenURLs.insert(standardizedURL)
      result.append(url)
    }

    return result
  }
}
