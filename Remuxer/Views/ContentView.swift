import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
  @ObservedObject var queue: ConversionQueue

  @AppStorage("isDeveloperModeEnabled") private var isDeveloperModeEnabled = false
  @AppStorage("lastSourceFolderPath") private var lastSourceFolderPath = ""

  @State private var selectedItemIDs: Set<QueueItem.ID> = []
  @State private var isDropTargeted = false

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
    .help("Choose where converted files are saved.")
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

  private func resetSelectedOutputName() {
    guard let selectedID = selectedDetailItem?.id else {
      return
    }

    queue.resetCustomOutputNames(for: [selectedID])
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

  private var rememberedSourceFolderURL: URL? {
    guard lastSourceFolderPath.isEmpty == false else {
      return nil
    }

    let url = URL(fileURLWithPath: lastSourceFolderPath)
    return FileManager.default.directoryExists(at: url) ? url : nil
  }

  private func rememberSourceFolder(from urls: [URL]) {
    guard let sourceFolderURL = urls.first?.deletingLastPathComponent() else {
      return
    }

    lastSourceFolderPath = sourceFolderURL.path
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

private struct EmptyQueueDropZone: View {
  let isDropTargeted: Bool
  let addFiles: () -> Void

  var body: some View {
    ZStack {
      VStack(spacing: 22) {
        Image(systemName: "film.stack")
          .font(.system(size: 50, weight: .light))
          .foregroundStyle(isDropTargeted ? Color.accentColor : Color.secondary)

        VStack(spacing: 7) {
          Text("Drop MKV files here")
            .font(.title2.weight(.semibold))

          Text("Add a batch, inspect the generated plans, then convert when everything is clear.")
            .font(.callout)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 430)
        }

        Button {
          addFiles()
        } label: {
          Label("Add MKV Files...", systemImage: "plus")
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .keyboardShortcut("o", modifiers: .command)
        .help("Add MKV files to the conversion queue.")
      }
      .padding(44)
      .frame(maxWidth: 620)
      .remuxerGlassPanel(cornerRadius: 28)
      .overlay {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
          .strokeBorder(
            isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.22),
            style: StrokeStyle(lineWidth: isDropTargeted ? 2 : 1, dash: [8, 7])
          )
          .allowsHitTesting(false)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(32)
  }
}

private struct RemuxerGlassPanel: ViewModifier {
  let cornerRadius: CGFloat

  func body(content: Content) -> some View {
    if #available(macOS 26.0, *) {
      content
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    } else {
      content
        .background(
          .regularMaterial,
          in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
    }
  }
}

extension View {
  func remuxerGlassPanel(cornerRadius: CGFloat) -> some View {
    modifier(RemuxerGlassPanel(cornerRadius: cornerRadius))
  }
}

private func droppedURL(from item: NSSecureCoding?) -> URL? {
  if let url = item as? URL {
    return url
  }

  if let data = item as? Data {
    return URL(dataRepresentation: data, relativeTo: nil)
  }

  return nil
}

extension FileManager {
  fileprivate func directoryExists(at url: URL) -> Bool {
    var isDirectory: ObjCBool = false
    let exists = fileExists(atPath: url.path, isDirectory: &isDirectory)
    return exists && isDirectory.boolValue
  }
}
