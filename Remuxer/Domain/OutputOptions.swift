import Foundation

enum OutputLocationMode: String, CaseIterable, Codable, Identifiable {
  case besideSource
  case selectedFolder
  case perSourceFolder

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .besideSource:
      "Beside Source"
    case .selectedFolder:
      "Selected Folder"
    case .perSourceFolder:
      "Folder Per File"
    }
  }
}

enum CollisionResolution: String, CaseIterable, Codable, Identifiable {
  case autoRename
  case replace
  case block

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .autoRename:
      "Auto Rename"
    case .replace:
      "Replace"
    case .block:
      "Block"
    }
  }
}

struct OutputOptions: Codable, Equatable {
  var locationMode: OutputLocationMode = .besideSource
  var selectedFolderURL: URL?
  var collisionResolution: CollisionResolution = .autoRename
}

struct OutputName: Equatable {
  let value: String

  init?(_ rawValue: String?) {
    guard let rawValue else {
      return nil
    }

    let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmedValue.isEmpty == false else {
      return nil
    }

    value = trimmedValue
  }
}
