import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
  @ObservedObject var queue: ConversionQueue

  @AppStorage("isDeveloperModeEnabled") private var isDeveloperModeEnabled = false
  @AppStorage("lastSourceFolderPath") var lastSourceFolderPath = ""

  @State private var selectedItemIDs: Set<QueueItem.ID> = []
  @State private var isDropTargeted = false
  @State private var seriesNaming = SeriesOutputNamingPreference()

  var body: some View {
    NavigationSplitView {
      QueueListView(
        queue: queue,
        selectedItemIDs: $selectedItemIDs
      )
      .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 380)
    } detail: {
      detailContent
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .toolbar { toolbarContent }
    .onDrop(
      of: [UTType.fileURL.identifier],
      isTargeted: $isDropTargeted,
      perform: openDroppedFiles
    )
    .overlay {
      if isDropTargeted, queue.items.isEmpty == false {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .stroke(Color.accentColor, lineWidth: 2)
          .padding(16)
          .allowsHitTesting(false)
      }
    }
    .onOpenURL { url in
      addSourceFiles([url])
    }
  }
}

extension ContentView {
  @ToolbarContentBuilder
  private var toolbarContent: some ToolbarContent {
    ToolbarItemGroup {
      if queue.items.isEmpty == false {
        IconOnlyButton(
          title: "Add Files",
          systemImage: "plus",
          help: "Add MKV files to the conversion queue."
        ) {
          presentSourceFilePicker()
        }
        .keyboardShortcut("o", modifiers: .command)
      }

      presetMenu
      outputMenu

      IconOnlyButton(
        title: "Analyze",
        systemImage: "waveform.path.ecg",
        help: "Analyze all queued files and build conversion plans."
      ) {
        Task { await queue.analyzeItems() }
      }
      .disabled(queue.items.isEmpty || queue.isWorking)

      IconOnlyButton(
        title: "Start",
        systemImage: "play.fill",
        help: "Start converting all ready files in the queue."
      ) {
        Task { await startQueueConversion() }
      }
      .disabled(canStartConversion == false)

      IconOnlyButton(
        title: "Cancel",
        systemImage: "stop.fill",
        help: "Cancel the active conversion."
      ) {
        queue.cancelActiveConversion()
      }
      .disabled(queue.isWorking == false)

      IconOnlyButton(
        title: "Clear Completed",
        systemImage: "checkmark.circle",
        help: "Remove completed files from the queue."
      ) {
        queue.clearCompleted()
      }
      .disabled(queue.canClearCompleted == false)
    }
  }

  private var presetMenu: some View {
    Menu {
      Picker("Default Preset", selection: $queue.defaultPreset) {
        ForEach(ConversionPreset.allCases) { preset in
          Text(preset.displayName).tag(preset)
        }
      }
      .pickerStyle(.inline)

      Divider()

      Button(applyPresetTitle) {
        queue.applyDefaultPreset(to: selectedItemIDs)
      }
      .disabled(queue.items.isEmpty || queue.isWorking)
    } label: {
      Label(queue.defaultPreset.displayName, systemImage: "slider.horizontal.3")
    }
    .iconControlTooltip("Choose the default conversion preset.")
  }

  private var outputMenu: some View {
    Menu {
      Picker("Destination", selection: $queue.outputOptions.locationMode) {
        ForEach(OutputLocationMode.allCases) { mode in
          Text(mode.displayName).tag(mode)
        }
      }
      .pickerStyle(.inline)

      Button("Choose Folder...") {
        presentDestinationFolderPicker()
      }

      if queue.recentDestinationURLs.isEmpty == false {
        Section("Recent") {
          ForEach(queue.recentDestinationURLs, id: \.self) { url in
            Button(url.path) {
              queue.chooseRecentDestination(url)
            }
          }
        }
      }

      if queue.savedDestinationURLs.isEmpty == false {
        Section("Saved") {
          ForEach(queue.savedDestinationURLs, id: \.self) { url in
            Button(url.path) {
              queue.chooseSavedDestination(url)
            }
          }
        }

        Section {
          Menu("Remove Saved") {
            ForEach(queue.savedDestinationURLs, id: \.self) { url in
              Button(url.lastPathComponent) {
                queue.removeSavedDestination(url)
              }
            }
          }
        }
      }

      Divider()

      Picker("Collisions", selection: $queue.outputOptions.collisionResolution) {
        ForEach(CollisionResolution.allCases) { resolution in
          Text(resolution.displayName).tag(resolution)
        }
      }
      .pickerStyle(.inline)

      Button("Save Current Location") {
        queue.saveSelectedDestination()
      }
      .disabled(queue.canSaveSelectedDestination == false)
    } label: {
      Label("Output", systemImage: "folder")
    }
    .iconControlTooltip("Choose where converted files are saved.")
    .disabled(queue.isWorking)
  }

  @ViewBuilder
  private var detailContent: some View {
    if queue.items.isEmpty {
      EmptyQueueDropZone(
        isDropTargeted: isDropTargeted,
        addFiles: presentSourceFilePicker
      )
    } else {
      PlanDetailView(
        item: selectedDetailItem,
        presetSelection: selectedPresetBinding,
        outputName: selectedOutputNameBinding,
        resetOutputName: resetSelectedOutputName,
        toolchainErrorMessage: queue.toolchainErrorMessage,
        queueItems: queue.items,
        selectedItemIDs: selectedItemIDs,
        seriesNaming: $seriesNaming,
        extractsSubtitleSidecars: $queue.outputOptions.extractSubtitleSidecars,
        removesSourceAfterSuccess: $queue.outputOptions.removeSourceAfterSuccess,
        isWorking: queue.isWorking,
        isDeveloperModeEnabled: isDeveloperModeEnabled
      )
    }
  }

  private var selectedDetailItem: QueueItem? {
    if let selectedID = selectedItemIDs.first {
      return queue.items.first { $0.id == selectedID }
    }

    return queue.items.first
  }

  private var selectedPresetBinding: Binding<ConversionPreset>? {
    guard let selectedID = selectedDetailItem?.id else {
      return nil
    }

    return Binding(
      get: {
        queue.items.first { $0.id == selectedID }?.selectedPreset ?? queue.defaultPreset
      },
      set: { queue.setPreset($0, for: selectedID) }
    )
  }

  private var selectedOutputNameBinding: Binding<String>? {
    guard let selectedID = selectedDetailItem?.id else {
      return nil
    }

    return Binding(
      get: {
        queue.items.first { $0.id == selectedID }?.customOutputName ?? ""
      },
      set: { queue.setCustomOutputName($0, for: selectedID) }
    )
  }

  private var applyPresetTitle: String {
    selectedItemIDs.isEmpty ? "Apply Preset to Queue" : "Apply Preset to Selection"
  }

  private var canStartConversion: Bool {
    queue.items.isEmpty == false
      && queue.isWorking == false
      && (shouldApplySeriesNaming == false || seriesNaming.sequence != nil)
  }

  private var shouldApplySeriesNaming: Bool {
    queue.items.count > 1 && seriesNaming.isEnabled
  }

  private func resetSelectedOutputName() {
    guard let selectedID = selectedDetailItem?.id else {
      return
    }

    queue.resetCustomOutputNames(for: [selectedID])
  }

  @MainActor
  private func startQueueConversion() async {
    seriesNaming.errorMessage = nil

    if shouldApplySeriesNaming {
      do {
        try queue.applyOutputNameSequence(
          prefix: seriesNaming.prefix,
          startNumberText: seriesNaming.startNumberText,
          to: batchRenameTargetIDs
        )
      } catch {
        seriesNaming.errorMessage = error.localizedDescription
        return
      }
    }

    await queue.startConversion()
  }

  private var batchRenameTargetIDs: Set<QueueItem.ID> {
    selectedItemIDs.count > 1 ? selectedItemIDs : []
  }

  private func addSourceFiles(_ urls: [URL]) {
    rememberSourceFolder(from: urls.filter(SupportedInputFile.isSupported))
    queue.addFiles(urls)

    if selectedItemIDs.isEmpty, let firstItemID = queue.items.first?.id {
      selectedItemIDs = [firstItemID]
    }
  }

  @MainActor
  private func presentSourceFilePicker() {
    let panel = NSOpenPanel()
    panel.title = "Add Video Files"
    panel.message = "Choose one or more MKV files to add to the queue."
    panel.prompt = "Add"
    panel.allowedContentTypes = SupportedInputFile.allowedContentTypes
    panel.allowsMultipleSelection = true
    panel.canChooseFiles = true
    panel.canChooseDirectories = false
    panel.resolvesAliases = true
    panel.directoryURL = rememberedSourceFolderURL

    panel.begin { response in
      guard response == .OK else {
        return
      }

      addSourceFiles(panel.urls)
    }
  }

  @MainActor
  private func presentDestinationFolderPicker() {
    let panel = NSOpenPanel()
    panel.title = "Choose Output Folder"
    panel.message = "Choose where converted files should be written."
    panel.prompt = "Choose"
    panel.allowsMultipleSelection = false
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.canCreateDirectories = true
    panel.resolvesAliases = true

    panel.begin { response in
      guard response == .OK, let folderURL = panel.urls.first else {
        return
      }

      queue.chooseDestinationFolder(folderURL)
    }
  }

  private func openDroppedFiles(_ providers: [NSItemProvider]) -> Bool {
    let fileProviders = providers.filter {
      $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
    }

    guard fileProviders.isEmpty == false else {
      return false
    }

    for provider in fileProviders {
      provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
        guard let url = droppedURL(from: item) else {
          return
        }

        Task { @MainActor in
          addSourceFiles([url])
        }
      }
    }

    return true
  }
}
