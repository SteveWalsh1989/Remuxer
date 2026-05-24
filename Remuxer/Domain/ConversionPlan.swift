import Foundation

enum PlanMode: String, Codable {
  case remux
  case transcode
  case archive

  var displayName: String {
    switch self {
    case .remux:
      "Remux"
    case .transcode:
      "Transcode"
    case .archive:
      "Archive"
    }
  }
}

struct PlanIssue: Codable, Equatable, Identifiable {
  enum Severity: String, Codable {
    case warning
    case blocker
  }

  let severity: Severity
  let message: String

  var id: String {
    "\(severity.rawValue):\(message)"
  }
}

struct ProcessCommand: Codable, Equatable, Identifiable {
  let executableName: String
  let arguments: [String]

  var id: String {
    displayString
  }

  var displayString: String {
    ([executableName] + arguments)
      .map(Self.displayArgument)
      .joined(separator: " ")
  }

  private static func displayArgument(_ argument: String) -> String {
    guard argument.contains(" ") || argument.contains("'") else {
      return argument
    }

    return "'\(argument.replacingOccurrences(of: "'", with: "'\\''"))'"
  }
}

struct PlannedOutput: Codable, Equatable {
  let videoURL: URL
  let sidecarURLs: [URL]
}

struct ConversionPlan: Codable, Equatable, Identifiable {
  let id: UUID
  let preset: ConversionPreset
  let mode: PlanMode
  let primaryCommand: ProcessCommand
  let subtitleExtractionCommands: [ProcessCommand]
  let warnings: [PlanIssue]
  let blockers: [PlanIssue]
  let output: PlannedOutput

  init(
    id: UUID = UUID(),
    preset: ConversionPreset,
    mode: PlanMode,
    primaryCommand: ProcessCommand,
    subtitleExtractionCommands: [ProcessCommand],
    warnings: [PlanIssue],
    blockers: [PlanIssue],
    output: PlannedOutput
  ) {
    self.id = id
    self.preset = preset
    self.mode = mode
    self.primaryCommand = primaryCommand
    self.subtitleExtractionCommands = subtitleExtractionCommands
    self.warnings = warnings
    self.blockers = blockers
    self.output = output
  }

  var canExecute: Bool {
    blockers.isEmpty
  }
}
