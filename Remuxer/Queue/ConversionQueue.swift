import Foundation

@MainActor
final class ConversionQueue: ObservableObject {
  @Published private(set) var items: [QueueItem] = []
  @Published var defaultPreset: ConversionPreset = .losslessMP4
  @Published var outputOptions = OutputOptions() {
    didSet {
      replanAnalyzedItems()
    }
  }
  @Published private(set) var isWorking = false
  @Published private(set) var toolchainErrorMessage: String?
  @Published private(set) var recentDestinationURLs: [URL] = []
  @Published private(set) var savedDestinationURLs: [URL] = []

  private let analyzer: MediaAnalyzing
  private let planner: ConversionPlanGenerating
  private let executor: ConversionExecuting
  private let toolLocator: ToolLocating
  private let destinationStore: DestinationPersisting
  private let outputPreparer: OutputPreparing
  private var shouldCancelActiveRun = false

  init(
    analyzer: MediaAnalyzing,
    planner: ConversionPlanGenerating,
    executor: ConversionExecuting,
    toolLocator: ToolLocating,
    destinationStore: DestinationPersisting = UserDefaultsDestinationStore(),
    outputPreparer: OutputPreparing = OutputPreparer()
  ) {
    self.analyzer = analyzer
    self.planner = planner
    self.executor = executor
    self.toolLocator = toolLocator
    self.destinationStore = destinationStore
    self.outputPreparer = outputPreparer
    recentDestinationURLs = destinationStore.loadRecentDestinations()
    savedDestinationURLs = destinationStore.loadSavedDestinations()
  }

  var readyCount: Int {
    items.filter { $0.status == .ready }.count
  }

  var completedCount: Int {
    items.filter { $0.status == .completed }.count
  }

  func addFiles(_ urls: [URL]) {
    let existingURLs = Set(items.map(\.sourceURL))
    let newItems =
      urls
      .filter(SupportedInputFile.isSupported)
      .filter { existingURLs.contains($0) == false }
      .map { QueueItem(sourceURL: $0, selectedPreset: defaultPreset) }

    items.append(contentsOf: newItems)
  }

  func removeItems(with ids: Set<QueueItem.ID>) {
    guard ids.isEmpty == false else {
      return
    }

    items.removeAll { ids.contains($0.id) }
  }

  func clearCompleted() {
    items.removeAll { $0.status == .completed }
  }

  func setPreset(_ preset: ConversionPreset, for id: QueueItem.ID) {
    updateItem(id) { item in
      item.selectedPreset = preset
      replan(&item)
    }
  }

  func setCustomOutputName(_ name: String, for id: QueueItem.ID) {
    updateItem(id) { item in
      item.customOutputName = name
      replan(&item)
    }
  }

  func resetCustomOutputNames(for ids: Set<QueueItem.ID>) {
    for id in effectiveTargetIDs(ids) {
      setCustomOutputName("", for: id)
    }
  }

  func applyDefaultPreset(to ids: Set<QueueItem.ID>) {
    let targetIDs = effectiveTargetIDs(ids)

    for id in targetIDs {
      setPreset(defaultPreset, for: id)
    }
  }

  func analyzeItems(with ids: Set<QueueItem.ID> = []) async {
    guard isWorking == false else {
      return
    }

    isWorking = true
    shouldCancelActiveRun = false
    defer { isWorking = false }

    do {
      _ = try toolLocator.locateToolchain()
      toolchainErrorMessage = nil
    } catch {
      toolchainErrorMessage = error.localizedDescription
      markTargetsAsFailed(ids, message: error.localizedDescription)
      return
    }

    for id in effectiveTargetIDs(ids) {
      guard shouldCancelActiveRun == false else {
        return
      }

      await analyzeItem(id: id)
    }
  }

  func startConversion(with ids: Set<QueueItem.ID> = []) async {
    guard isWorking == false else {
      return
    }

    isWorking = true
    shouldCancelActiveRun = false
    defer { isWorking = false }

    do {
      _ = try toolLocator.locateToolchain()
      toolchainErrorMessage = nil
    } catch {
      toolchainErrorMessage = error.localizedDescription
      markTargetsAsFailed(ids, message: error.localizedDescription)
      return
    }

    for id in effectiveTargetIDs(ids) {
      guard shouldCancelActiveRun == false else {
        return
      }

      if item(with: id)?.media == nil {
        await analyzeItem(id: id)
      }

      guard var item = item(with: id), let plan = item.plan else {
        continue
      }

      guard plan.canExecute else {
        item.status = .blocked
        replaceItem(item)
        continue
      }

      await run(plan: plan, for: id)
    }
  }

  func cancelActiveConversion() {
    shouldCancelActiveRun = true
    executor.cancel()
  }

  func retryItems(with ids: Set<QueueItem.ID>) async {
    for id in effectiveTargetIDs(ids) {
      updateItem(id) { item in
        item.status = .queued
        item.progress = 0
      }
    }

    await analyzeItems(with: ids)
  }

  private func analyzeItem(id: QueueItem.ID) async {
    guard let sourceURL = item(with: id)?.sourceURL else {
      return
    }

    updateItem(id) { item in
      item.status = .analyzing
      item.progress = 0
      item.logLines = []
    }

    do {
      let media = try await analyzer.analyze(url: sourceURL)

      updateItem(id) { item in
        item.media = media
        replan(&item)
      }
    } catch {
      updateItem(id) { item in
        item.status = .failed(error.localizedDescription)
        item.logLines.append(error.localizedDescription)
      }
    }
  }

  private func run(plan: ConversionPlan, for id: QueueItem.ID) async {
    updateItem(id) { item in
      item.status = .converting
      item.progress = 0
      item.logLines.append("Starting \(plan.preset.displayName)")
    }

    do {
      try outputPreparer.prepareOutput(for: plan.output)

      for command in plan.subtitleExtractionCommands {
        try await executor.run(
          command,
          duration: nil,
          progress: { _ in },
          log: { [weak self] line in
            Task { @MainActor in
              self?.appendLog(line, to: id)
            }
          }
        )
      }

      try await executor.run(
        plan.primaryCommand,
        duration: item(with: id)?.media?.duration,
        progress: { [weak self] progress in
          Task { @MainActor in
            self?.updateItem(id) { item in
              item.progress = progress
            }
          }
        },
        log: { [weak self] line in
          Task { @MainActor in
            self?.appendLog(line, to: id)
          }
        }
      )

      updateItem(id) { item in
        item.progress = 1
        item.status = .completed
        item.logLines.append("Completed")
      }
    } catch {
      updateItem(id) { item in
        item.status = shouldCancelActiveRun ? .queued : .failed(error.localizedDescription)
        item.logLines.append(error.localizedDescription)
      }
    }
  }

  private func replanAnalyzedItems() {
    for id in items.map(\.id) {
      updateItem(id) { item in
        guard item.media != nil else {
          return
        }

        replan(&item)
      }
    }
  }

  private func replan(_ item: inout QueueItem) {
    guard let media = item.media else {
      return
    }

    do {
      let plan = try planner.makePlan(
        for: media,
        preset: item.selectedPreset,
        outputOptions: outputOptions,
        customOutputName: item.customOutputName
      )
      item.plan = plan
      item.planningErrorMessage = nil
      item.status = plan.canExecute ? .ready : .blocked
    } catch let error as OutputPathError {
      item.plan = nil
      item.planningErrorMessage = error.localizedDescription
      item.status = .blocked
    } catch {
      item.plan = nil
      item.planningErrorMessage = error.localizedDescription
      item.status = .failed(error.localizedDescription)
      item.logLines.append(error.localizedDescription)
    }
  }

  private func effectiveTargetIDs(_ ids: Set<QueueItem.ID>) -> [QueueItem.ID] {
    if ids.isEmpty {
      return items.map(\.id)
    }

    let requested = ids
    return items.map(\.id).filter { requested.contains($0) }
  }

  private func markTargetsAsFailed(_ ids: Set<QueueItem.ID>, message: String) {
    for id in effectiveTargetIDs(ids) {
      updateItem(id) { item in
        item.status = .failed(message)
        item.logLines.append(message)
      }
    }
  }

  private func updateItem(_ id: QueueItem.ID, mutate: (inout QueueItem) -> Void) {
    guard let index = items.firstIndex(where: { $0.id == id }) else {
      return
    }

    mutate(&items[index])
  }

  private func replaceItem(_ item: QueueItem) {
    guard let index = items.firstIndex(where: { $0.id == item.id }) else {
      return
    }

    items[index] = item
  }

  private func item(with id: QueueItem.ID) -> QueueItem? {
    items.first { $0.id == id }
  }

  private func appendLog(_ line: String, to id: QueueItem.ID) {
    updateItem(id) { item in
      item.logLines.append(line)
    }
  }

}

extension ConversionQueue {
  var canSaveSelectedDestination: Bool {
    guard outputOptions.locationMode != .besideSource else {
      return false
    }

    guard let selectedFolderURL = outputOptions.selectedFolderURL else {
      return false
    }

    return savedDestinationURLs.containsDestination(selectedFolderURL) == false
  }

  func chooseDestinationFolder(_ url: URL) {
    outputOptions.selectedFolderURL = url
    outputOptions.locationMode = .selectedFolder
    rememberDestination(url)
  }

  func chooseRecentDestination(_ url: URL) {
    outputOptions.selectedFolderURL = url
    outputOptions.locationMode = .selectedFolder
    rememberDestination(url)
  }

  func chooseSavedDestination(_ url: URL) {
    outputOptions.selectedFolderURL = url
    outputOptions.locationMode = .selectedFolder
    rememberDestination(url)
  }

  func saveSelectedDestination() {
    guard outputOptions.locationMode != .besideSource else {
      return
    }

    guard let selectedFolderURL = outputOptions.selectedFolderURL else {
      return
    }

    savedDestinationURLs.removeDestination(selectedFolderURL)
    savedDestinationURLs.insert(selectedFolderURL, at: 0)
    destinationStore.saveSavedDestinations(savedDestinationURLs)
  }

  func removeSavedDestination(_ url: URL) {
    savedDestinationURLs.removeDestination(url)
    destinationStore.saveSavedDestinations(savedDestinationURLs)
  }

  private func rememberDestination(_ url: URL) {
    recentDestinationURLs.removeDestination(url)
    recentDestinationURLs.insert(url, at: 0)

    if recentDestinationURLs.count > 6 {
      recentDestinationURLs = Array(recentDestinationURLs.prefix(6))
    }

    destinationStore.saveRecentDestinations(recentDestinationURLs)
  }
}

extension Array where Element == URL {
  fileprivate mutating func removeDestination(_ url: URL) {
    let normalizedURL = url.standardizedFileURL
    removeAll { $0.standardizedFileURL == normalizedURL }
  }

  fileprivate func containsDestination(_ url: URL) -> Bool {
    let normalizedURL = url.standardizedFileURL
    return contains { $0.standardizedFileURL == normalizedURL }
  }
}
