import SwiftUI

struct QueueListView: View {
  @ObservedObject var queue: ConversionQueue
  @Binding var selectedItemIDs: Set<QueueItem.ID>

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
    .overlay {
      if queue.items.isEmpty {
        EmptyQueueView()
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
  var body: some View {
    VStack(spacing: 12) {
      Image(systemName: "tray.and.arrow.down")
        .font(.system(size: 42, weight: .light))
        .foregroundStyle(.secondary)

      VStack(spacing: 4) {
        Text("Drop MKV files here")
          .font(.headline)

        Text("Add one file or a batch from Finder to build a conversion queue.")
          .font(.callout)
          .foregroundStyle(.secondary)
      }
    }
  }
}
