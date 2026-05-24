import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
  @ObservedObject var queue: ConversionQueue

  @State private var selectedItemIDs: Set<QueueItem.ID> = []
  @State private var isFileImporterPresented = false
  @State private var isFolderImporterPresented = false
  @State private var isDropTargeted = false

  var body: some View {
    HSplitView {
      VStack(spacing: 0) {
        QueueControlBar(
          queue: queue,
          selectedItemIDs: selectedItemIDs,
          addFiles: { isFileImporterPresented = true },
          chooseFolder: { isFolderImporterPresented = true }
        )

        Divider()

        QueueListView(
          queue: queue,
          selectedItemIDs: $selectedItemIDs,
          isDropTargeted: isDropTargeted,
          addFiles: { isFileImporterPresented = true }
        )
      }
      .frame(
        minWidth: 720,
        idealWidth: 820,
        maxWidth: .infinity,
        maxHeight: .infinity,
        alignment: .top
      )

      Divider()

      PlanDetailView(item: selectedDetailItem)
        .frame(
          minWidth: 340,
          idealWidth: 390,
          maxWidth: 460,
          maxHeight: .infinity,
          alignment: .top
        )
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .toolbar {
      ToolbarItemGroup {
        Button {
          isFileImporterPresented = true
        } label: {
          Label("Add MKV Files", systemImage: "plus")
        }
        .keyboardShortcut("o", modifiers: .command)
        .help("Add MKV Files")

        Button {
          Task { await queue.analyzeItems(with: selectedItemIDs) }
        } label: {
          Label("Analyze", systemImage: "waveform.path.ecg")
        }
        .disabled(queue.items.isEmpty || queue.isWorking)

        Button {
          Task { await queue.startConversion(with: selectedItemIDs) }
        } label: {
          Label("Start", systemImage: "play.fill")
        }
        .disabled(queue.items.isEmpty || queue.isWorking)

        Button {
          queue.cancelActiveConversion()
        } label: {
          Label("Cancel", systemImage: "stop.fill")
        }
        .disabled(queue.isWorking == false)

        Button {
          queue.clearCompleted()
        } label: {
          Label("Clear Completed", systemImage: "checkmark.circle")
        }
        .disabled(queue.completedCount == 0 || queue.isWorking)
      }
    }
    .fileImporter(
      isPresented: $isFileImporterPresented,
      allowedContentTypes: SupportedInputFile.allowedContentTypes,
      allowsMultipleSelection: true
    ) { result in
      if case .success(let urls) = result {
        queue.addFiles(urls)
      }
    }
    .fileImporter(
      isPresented: $isFolderImporterPresented,
      allowedContentTypes: [.folder],
      allowsMultipleSelection: false
    ) { result in
      if case .success(let urls) = result, let folderURL = urls.first {
        queue.chooseDestinationFolder(folderURL)
      }
    }
    .onDrop(
      of: [UTType.fileURL.identifier],
      isTargeted: $isDropTargeted,
      perform: openDroppedFiles
    )
    .overlay {
      if isDropTargeted {
        RoundedRectangle(cornerRadius: 8)
          .stroke(Color.accentColor, lineWidth: 2)
          .padding(18)
          .allowsHitTesting(false)
      }
    }
    .onOpenURL { url in
      queue.addFiles([url])
    }
  }

  private var selectedDetailItem: QueueItem? {
    if let selectedID = selectedItemIDs.first {
      return queue.items.first { $0.id == selectedID }
    }

    return queue.items.first
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
          queue.addFiles([url])
        }
      }
    }

    return true
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
