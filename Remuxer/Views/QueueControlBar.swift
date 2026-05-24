import SwiftUI

struct QueueControlBar: View {
  @ObservedObject var queue: ConversionQueue
  let selectedItemIDs: Set<QueueItem.ID>
  let addFiles: () -> Void
  let chooseFolder: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .center, spacing: 12) {
        VStack(alignment: .leading, spacing: 3) {
          Text("Queue")
            .font(.headline)

          Text(queueSummary)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }

        Spacer(minLength: 20)

        Button {
          addFiles()
        } label: {
          Label("Add MKV Files...", systemImage: "plus")
        }
        .buttonStyle(.bordered)
        .disabled(queue.isWorking)

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
        .buttonStyle(.borderedProminent)
        .disabled(queue.items.isEmpty || queue.isWorking)

        Button {
          queue.cancelActiveConversion()
        } label: {
          Label("Cancel", systemImage: "stop.fill")
        }
        .disabled(queue.isWorking == false)
      }

      HStack(spacing: 12) {
        Picker("Preset", selection: $queue.defaultPreset) {
          ForEach(ConversionPreset.allCases) { preset in
            Text(preset.displayName).tag(preset)
          }
        }
        .frame(width: 190)

        Button {
          queue.applyDefaultPreset(to: selectedItemIDs)
        } label: {
          Label(applyPresetTitle, systemImage: "square.stack.3d.up")
        }
        .disabled(queue.items.isEmpty || queue.isWorking)

        Divider()
          .frame(height: 22)

        Picker("Output", selection: $queue.outputOptions.locationMode) {
          ForEach(OutputLocationMode.allCases) { mode in
            Text(mode.displayName).tag(mode)
          }
        }
        .frame(width: 180)

        Button {
          chooseFolder()
        } label: {
          Label("Choose Folder", systemImage: "folder")
        }

        if queue.recentDestinationURLs.isEmpty == false {
          Menu {
            ForEach(queue.recentDestinationURLs, id: \.self) { url in
              Button(url.path) {
                queue.chooseRecentDestination(url)
              }
            }
          } label: {
            Label("Recent", systemImage: "clock")
          }
        }

        Menu {
          Button("Save Current Location") {
            queue.saveSelectedDestination()
          }
          .disabled(queue.canSaveSelectedDestination == false)

          if queue.savedDestinationURLs.isEmpty == false {
            Divider()

            ForEach(queue.savedDestinationURLs, id: \.self) { url in
              Button(url.path) {
                queue.chooseSavedDestination(url)
              }
            }

            Divider()

            Menu("Remove Saved") {
              ForEach(queue.savedDestinationURLs, id: \.self) { url in
                Button(url.lastPathComponent) {
                  queue.removeSavedDestination(url)
                }
              }
            }
          }
        } label: {
          Label("Saved", systemImage: "star")
        }

        Picker("Collision", selection: $queue.outputOptions.collisionResolution) {
          ForEach(CollisionResolution.allCases) { resolution in
            Text(resolution.displayName).tag(resolution)
          }
        }
        .frame(width: 145)
      }

      HStack(spacing: 10) {
        StatusChip(title: "\(queue.items.count)", detail: "items")
        StatusChip(title: "\(queue.readyCount)", detail: "ready")
        StatusChip(title: "\(queue.completedCount)", detail: "done")

        if let errorMessage = queue.toolchainErrorMessage {
          Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
            .font(.caption)
            .foregroundStyle(.orange)
            .lineLimit(1)
        }

        Spacer()

        Text("Destination: \(QueueFormatters.path(queue.outputOptions.selectedFolderURL))")
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .truncationMode(.middle)
      }
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
  }

  private var queueSummary: String {
    if queue.items.isEmpty {
      return "No source files added"
    }

    if selectedItemIDs.isEmpty {
      return "\(queue.items.count) queued, \(stateSummary)"
    }

    return "\(selectedItemIDs.count) selected, \(stateSummary)"
  }

  private var stateSummary: String {
    "\(queue.readyCount) ready, \(queue.completedCount) done"
  }

  private var applyPresetTitle: String {
    selectedItemIDs.isEmpty ? "Apply to Queue" : "Apply to Selection"
  }
}

private struct StatusChip: View {
  let title: String
  let detail: String

  var body: some View {
    HStack(spacing: 4) {
      Text(title)
        .font(.caption.monospacedDigit().weight(.semibold))

      Text(detail)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(.quaternary, in: Capsule())
  }
}
