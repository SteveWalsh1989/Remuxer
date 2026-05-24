import SwiftUI

struct QueueListView: View {
  @ObservedObject var queue: ConversionQueue
  @Binding var selectedItemIDs: Set<QueueItem.ID>
  let isDropTargeted: Bool
  let addFiles: () -> Void

  var body: some View {
    List(selection: $selectedItemIDs) {
      ForEach(queue.items) { item in
        QueueItemRow(
          item: item,
          presetSelection: Binding(
            get: { item.selectedPreset },
            set: { queue.setPreset($0, for: item.id) }
          ),
          outputName: Binding(
            get: { item.customOutputName },
            set: { queue.setCustomOutputName($0, for: item.id) }
          )
        )
        .tag(item.id)
        .contextMenu {
          Button("Analyze") {
            Task { await queue.analyzeItems(with: [item.id]) }
          }

          Button("Retry") {
            Task { await queue.retryItems(with: [item.id]) }
          }

          Divider()

          Button("Reset Output Name") {
            queue.resetCustomOutputNames(for: [item.id])
          }

          Button("Remove") {
            queue.removeItems(with: [item.id])
          }
        }
      }
    }
    .listStyle(.inset)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .overlay {
      if queue.items.isEmpty {
        EmptyQueueView(
          isDropTargeted: isDropTargeted,
          addFiles: addFiles
        )
      }
    }
  }
}

private struct QueueItemRow: View {
  let item: QueueItem
  @Binding var presetSelection: ConversionPreset
  @Binding var outputName: String

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .center, spacing: 12) {
        VStack(alignment: .leading, spacing: 3) {
          Text(item.fileName)
            .font(.headline)
            .lineLimit(1)

          Text(item.sourceURL.path)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.middle)
        }

        Spacer(minLength: 12)

        Picker("Preset", selection: $presetSelection) {
          ForEach(ConversionPreset.allCases) { preset in
            Text(preset.displayName).tag(preset)
          }
        }
        .labelsHidden()
        .frame(width: 150)

        TextField(item.defaultOutputName, text: $outputName)
          .textFieldStyle(.roundedBorder)
          .frame(width: 190)
          .help("Output file name")

        StatusBadge(status: item.status)
          .frame(width: 96, alignment: .trailing)
      }

      HStack(spacing: 14) {
        Label(item.streamSummary, systemImage: "film.stack")
        Label(
          item.issueSummary.isEmpty ? "No plan" : item.issueSummary,
          systemImage: "list.bullet.clipboard")

        if let plan = item.plan {
          Label(plan.output.videoURL.lastPathComponent, systemImage: "arrow.down.doc")
            .lineLimit(1)
            .truncationMode(.middle)
        } else if let planningErrorMessage = item.planningErrorMessage {
          Label(planningErrorMessage, systemImage: "exclamationmark.triangle")
            .lineLimit(1)
            .truncationMode(.middle)
        }

        Spacer()

        if item.status == .converting {
          ProgressView(value: item.progress)
            .frame(width: 120)

          Text(QueueFormatters.percentage(item.progress))
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
            .frame(width: 38, alignment: .trailing)
        }
      }
      .font(.caption)
      .foregroundStyle(.secondary)
    }
    .padding(.vertical, 6)
    .listRowInsets(EdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14))
  }
}

private struct StatusBadge: View {
  let status: QueueItemStatus

  var body: some View {
    Text(status.displayName)
      .font(.caption.weight(.semibold))
      .foregroundStyle(foregroundStyle)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(backgroundStyle, in: Capsule())
  }

  private var foregroundStyle: Color {
    switch status {
    case .blocked, .failed:
      .red
    case .completed:
      .green
    case .converting, .analyzing:
      .blue
    case .queued, .ready:
      .primary
    }
  }

  private var backgroundStyle: Color {
    foregroundStyle.opacity(0.14)
  }
}

private struct EmptyQueueView: View {
  let isDropTargeted: Bool
  let addFiles: () -> Void

  var body: some View {
    VStack(spacing: 18) {
      Image(systemName: "film.stack")
        .font(.system(size: 44, weight: .light))
        .foregroundStyle(isDropTargeted ? Color.accentColor : Color.secondary)

      VStack(spacing: 5) {
        Text("Drop MKV files here")
          .font(.title3.weight(.semibold))

        Text("Plans, warnings, and blockers appear before conversion starts.")
          .font(.callout)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }

      Button {
        addFiles()
      } label: {
        Label("Add MKV Files...", systemImage: "plus")
      }
      .buttonStyle(.borderedProminent)
    }
    .padding(28)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .strokeBorder(
          isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.28),
          style: StrokeStyle(lineWidth: isDropTargeted ? 2 : 1, dash: [7, 6])
        )
        .allowsHitTesting(false)
    }
    .padding(28)
  }
}
