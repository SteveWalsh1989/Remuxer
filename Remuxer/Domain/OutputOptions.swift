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
  var removeSourceAfterSuccess = false
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

enum OutputNameSequenceError: LocalizedError, Equatable {
  case invalidStartNumber

  var errorDescription: String? {
    switch self {
    case .invalidStartNumber:
      "Start number must use digits."
    }
  }
}

struct OutputNameSequence: Equatable {
  let prefix: String
  let startNumber: Int
  let minimumDigitCount: Int

  init(prefix: String, startNumberText: String) throws {
    guard let parsedStartNumber = Self.parseStartNumber(startNumberText) else {
      throw OutputNameSequenceError.invalidStartNumber
    }

    self.prefix = prefix
    startNumber = parsedStartNumber.number
    minimumDigitCount = parsedStartNumber.minimumDigitCount
  }

  static func isValidStartNumber(_ rawValue: String) -> Bool {
    parseStartNumber(rawValue) != nil
  }

  func name(at offset: Int) -> String {
    prefix + paddedNumber(startNumber + offset)
  }

  func names(count: Int) -> [String] {
    guard count > 0 else {
      return []
    }

    return (0..<count).map { name(at: $0) }
  }

  private func paddedNumber(_ number: Int) -> String {
    let rawNumber = String(number)
    let paddingCount = max(0, minimumDigitCount - rawNumber.count)
    return String(repeating: "0", count: paddingCount) + rawNumber
  }

  private static func parseStartNumber(_ rawValue: String) -> (
    number: Int,
    minimumDigitCount: Int
  )? {
    let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    let digits = CharacterSet(charactersIn: "0123456789")

    guard trimmedValue.isEmpty == false,
      trimmedValue.unicodeScalars.allSatisfy({ digits.contains($0) }),
      let number = Int(trimmedValue)
    else {
      return nil
    }

    return (number, trimmedValue.count)
  }
}
