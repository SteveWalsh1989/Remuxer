import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
  @ObservedObject var queue: ConversionQueue

  @AppStorage("isDeveloperModeEnabled") private var isDeveloperModeEnabled = false
  @AppStorage("lastSourceFolderPath") var lastSourceFolderPath = ""

  @State private var selectedItemIDs: Set<QueueItem.ID> = []
  @State private var isDropTargeted = false
  @State private var isBatchRenameSheetPresented = false

  var body: some View {
    NavigationSplitView {
      QueueListView(
        queue: queue,
        selectedItemIDs: $selectedItemIDs,
        isDeveloperModeEnabled: $isDeveloperModeEnabled
      )
      .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 380)
    } detail: {
      detailContent
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .toolbar { toolbarContent }
    .sheet(isPresented: $isBatchRenameSheetPresented) {
      OutputNameSequenceSheet(
        targetItems: batchRenameTargetItems,
        isWorking: queue.isWorking,
        apply: applyOutputNameSequence
      )
    }
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
        Button {
          presentSourceFilePicker()
        } label: {
          Label("Add Files", systemImage: "plus")
        }
        .keyboardShortcut("o", modifiers: .command)
        .help("Add MKV files to the conversion queue.")
      }

      presetMenu
      outputMenu

      Button {
        Task { await queue.analyzeItems(with: selectedItemIDs) }
      } label: {
        Label("Analyze", systemImage: "waveform.path.ecg")
      }
      .disabled(queue.items.isEmpty || queue.isWorking)
      .help("Analyze queued files and build conversion plans.")

      Button {
        Task { await queue.startConversion(with: selectedItemIDs) }
      } label: {
        Label("Start", systemImage: "play.fill")
      }
      .disabled(queue.items.isEmpty || queue.isWorking)
      .help("Start converting ready files.")

      Button {
        queue.cancelActiveConversion()
      } label: {
        Label("Cancel", systemImage: "stop.fill")
      }
      .disabled(queue.isWorking == false)
      .help("Cancel the active conversion.")

      Button {
        queue.clearCompleted()
      } label: {
        Label("Clear Completed", systemImage: "checkmark.circle")
      }
      .disabled(queue.completedCount == 0 || queue.isWorking)
      .help("Remove completed files from the queue.")
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
    .help("Choose the default conversion preset.")
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

      Button(batchRenameTitle) {
        isBatchRenameSheetPresented = true
      }
      .disabled(queue.items.isEmpty || queue.isWorking)

      Divider()

      Picker("Collisions", selection: $queue.outputOptions.collisionResolution) {
        ForEach(CollisionResolution.allCases) { resolution in
          Text(resolution.displayName).tag(resolution)
        }
      }
      .pickerStyle(.inline)

      Toggle(isOn: $queue.outputOptions.removeSourceAfterSuccess) {
        Label("Remove Originals After Success", systemImage: "trash")
      }

      Button("Save Current Location") {
        queue.saveSelectedDestination()
      }
      .disabled(queue.canSaveSelectedDestination == false)
    } label: {
      Label("Output", systemImage: "folder")
    }
    .help("Choose where converted files are saved.")
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
        removesSourceAfterSuccess: queue.outputOptions.removeSourceAfterSuccess,
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

  private var batchRenameTitle: String {
    selectedItemIDs.isEmpty ? "Batch Rename Queue..." : "Batch Rename Selection..."
  }

  private var batchRenameTargetItems: [QueueItem] {
    guard selectedItemIDs.isEmpty == false else {
      return queue.items
    }

    return queue.items.filter { selectedItemIDs.contains($0.id) }
  }

  private func resetSelectedOutputName() {
    guard let selectedID = selectedDetailItem?.id else {
      return
    }

    queue.resetCustomOutputNames(for: [selectedID])
  }

  private func applyOutputNameSequence(prefix: String, startNumberText: String) throws {
    try queue.applyOutputNameSequence(
      prefix: prefix,
      startNumberText: startNumberText,
      to: selectedItemIDs
    )
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
    panel.title = "Add MKV Files"
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
