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
        "Remuxer's FFmpeg runtime is missing ffmpeg.",
        "This build needs ffmpeg and ffprobe in the app bundle runtime folder,",
        "or a configured runtime folder for development.",
      ].joined(separator: " ")
    case .missingFFprobe:
      [
        "Remuxer's FFmpeg runtime is missing ffprobe.",
        "This build needs ffmpeg and ffprobe in the app bundle runtime folder,",
        "or a configured runtime folder for development.",
      ].joined(separator: " ")
    }
  }
}

struct ProcessToolLocator: ToolchainManaging {
  static let defaultSearchDirectories: [URL] = []

  static var defaultBundledSearchDirectories: [URL] {
    guard let resourceURL = Bundle.main.resourceURL else {
      return []
    }

    return [
      resourceURL.appendingPathComponent("FFmpeg/bin")
    ]
  }

  var searchDirectories: [URL]
  var bundledSearchDirectories: [URL]
  private let configurationStore: ToolchainConfigurationPersisting

  init(
    searchDirectories: [URL] = Self.defaultSearchDirectories,
    bundledSearchDirectories: [URL] = Self.defaultBundledSearchDirectories,
    configurationStore: ToolchainConfigurationPersisting = UserDefaultsToolchainConfigurationStore()
  ) {
    self.searchDirectories = searchDirectories
    self.bundledSearchDirectories = bundledSearchDirectories
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
    var directories = bundledSearchDirectories

    if let configuredDirectoryURL {
      directories.append(configuredDirectoryURL)
    }

    directories.append(contentsOf: searchDirectories)
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
