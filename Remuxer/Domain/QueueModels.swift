import Foundation

enum QueueItemStatus: Equatable {
  case queued
  case analyzing
  case ready
  case converting
  case completed
  case failed(String)
  case blocked

  var displayName: String {
    switch self {
    case .queued:
      "Queued"
    case .analyzing:
      "Analyzing"
    case .ready:
      "Ready"
    case .converting:
      "Converting"
    case .completed:
      "Completed"
    case .failed:
      "Failed"
    case .blocked:
      "Blocked"
    }
  }
}

struct QueueItem: Identifiable, Equatable {
  let id: UUID
  let sourceURL: URL
  var selectedPreset: ConversionPreset
  var status: QueueItemStatus
  var media: ProbedMediaFile?
  var plan: ConversionPlan?
  var progress: Double
  var logLines: [String]
  var customOutputName: String
  var planningErrorMessage: String?

  init(
    id: UUID = UUID(),
    sourceURL: URL,
    selectedPreset: ConversionPreset = .losslessMP4,
    status: QueueItemStatus = .queued,
    media: ProbedMediaFile? = nil,
    plan: ConversionPlan? = nil,
    progress: Double = 0,
    logLines: [String] = [],
    customOutputName: String = "",
    planningErrorMessage: String? = nil
  ) {
    self.id = id
    self.sourceURL = sourceURL
    self.selectedPreset = selectedPreset
    self.status = status
    self.media = media
    self.plan = plan
    self.progress = progress
    self.logLines = logLines
    self.customOutputName = customOutputName
    self.planningErrorMessage = planningErrorMessage
  }

  var fileName: String {
    sourceURL.lastPathComponent
  }

  var streamSummary: String {
    guard let media else {
      return "Not analyzed"
    }

    return
      "\(media.videoStreams.count)V \(media.audioStreams.count)A \(media.subtitleStreams.count)S"
  }

  var defaultOutputName: String {
    sourceURL.deletingPathExtension().lastPathComponent
  }

  var blockingIssueMessages: [String] {
    var messages: [String] = []

    if let planningErrorMessage {
      messages.append(planningErrorMessage)
    }

    if case .failed(let message) = status {
      messages.append(message)
    }

    if let plan {
      messages.append(contentsOf: plan.blockers.map(\.message))
    }

    return messages
  }
}
