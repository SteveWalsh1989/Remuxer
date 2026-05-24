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

struct BatchProgressSnapshot: Equatable {
  let totalCount: Int
  let completedCount: Int
  let progress: Double
  let estimatedTimeRemaining: TimeInterval?

  var hasItems: Bool {
    totalCount > 0
  }

  static func make(
    items: [QueueItem],
    targetIDs: [QueueItem.ID],
    isWorking: Bool,
    startedAt: Date?,
    now: Date
  ) -> BatchProgressSnapshot {
    let targetItems = items.filteredByTargetIDs(targetIDs)
    let totalCount = targetItems.count

    guard totalCount > 0 else {
      return BatchProgressSnapshot(
        totalCount: 0,
        completedCount: 0,
        progress: 0,
        estimatedTimeRemaining: nil
      )
    }

    let completedCount = targetItems.filter { $0.status == .completed }.count
    let progress = progressFraction(for: targetItems)
    let estimatedTimeRemaining = estimateRemainingTime(
      for: targetItems,
      isWorking: isWorking,
      startedAt: startedAt,
      now: now
    )

    return BatchProgressSnapshot(
      totalCount: totalCount,
      completedCount: completedCount,
      progress: progress,
      estimatedTimeRemaining: estimatedTimeRemaining
    )
  }

  private static func progressFraction(for items: [QueueItem]) -> Double {
    let totalUnits = Double(items.count)
    let completedUnits = items.reduce(0) { partialResult, item in
      partialResult + item.progressContribution
    }

    return min(max(completedUnits / totalUnits, 0), 1)
  }

  private static func estimateRemainingTime(
    for items: [QueueItem],
    isWorking: Bool,
    startedAt: Date?,
    now: Date
  ) -> TimeInterval? {
    guard isWorking,
      items.contains(where: { $0.status == .converting }),
      let startedAt
    else {
      return nil
    }

    let elapsed = now.timeIntervalSince(startedAt)
    guard elapsed >= 15 else {
      return nil
    }

    guard let durationWeightedProgress = durationWeightedProgress(for: items),
      durationWeightedProgress >= 0.05,
      durationWeightedProgress < 1
    else {
      return nil
    }

    return max(0, elapsed / durationWeightedProgress - elapsed)
  }

  private static func durationWeightedProgress(for items: [QueueItem]) -> Double? {
    let durations = items.map(\.positiveMediaDuration)
    guard durations.allSatisfy({ $0 != nil }) else {
      return nil
    }

    let totalDuration = durations.compactMap(\.self).reduce(0, +)
    guard totalDuration > 0 else {
      return nil
    }

    let completedDuration = items.reduce(0) { partialResult, item in
      partialResult + (item.positiveMediaDuration ?? 0) * item.progressContribution
    }

    return min(max(completedDuration / totalDuration, 0), 1)
  }
}

extension Array where Element == QueueItem {
  fileprivate func filteredByTargetIDs(_ targetIDs: [QueueItem.ID]) -> [QueueItem] {
    guard targetIDs.isEmpty == false else {
      return self
    }

    let targets = Set(targetIDs)
    return filter { targets.contains($0.id) }
  }
}

extension QueueItem {
  fileprivate var progressContribution: Double {
    switch status {
    case .completed:
      1
    case .converting:
      min(max(progress, 0), 1)
    case .queued, .analyzing, .ready, .failed, .blocked:
      0
    }
  }

  fileprivate var positiveMediaDuration: TimeInterval? {
    guard let duration = media?.duration, duration > 0 else {
      return nil
    }

    return duration
  }
}
