import SwiftUI

struct QueueListView: View {
  @ObservedObject var queue: ConversionQueue
  @Binding var selectedItemIDs: Set<QueueItem.ID>

  var body: some View {
    List(selection: $selectedItemIDs) {
      if queue.items.isEmpty == false {
        Section("Queue") {
          ForEach(queue.items) { item in
            QueueSidebarRow(item: item)
              .tag(item.id)
              .contextMenu {
                itemContextMenu(for: item)
              }
          }
        }
      }
    }
    .listStyle(.sidebar)
    .overlay {
      if queue.items.isEmpty {
        SidebarEmptyState()
      }
    }
  }

  @ViewBuilder
  private func itemContextMenu(for item: QueueItem) -> some View {
    Button("Analyze") {
      Task { await queue.analyzeItems(with: [item.id]) }
    }

    Button("Retry") {
      Task { await queue.retryItems(with: [item.id]) }
    }

    Menu("Preset") {
      ForEach(ConversionPreset.allCases) { preset in
        Button(preset.displayName) {
          queue.setPreset(preset, for: item.id)
        }
      }
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

private struct QueueSidebarRow: View {
  let item: QueueItem

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: statusSymbol)
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(statusColor)
        .frame(width: 18)

      VStack(alignment: .leading, spacing: 3) {
        Text(item.fileName)
          .font(.body)
          .lineLimit(1)

        HStack(spacing: 5) {
          Text(item.selectedPreset.displayName)
          Text("·")
          Text(item.status.displayName)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)

        if item.issueSummary.isEmpty == false {
          Text(item.issueSummary)
            .font(.caption2)
            .foregroundStyle(issueColor)
            .lineLimit(1)
        }
      }

      Spacer(minLength: 6)

      if item.status == .converting {
        ProgressView(value: item.progress)
          .controlSize(.small)
          .frame(width: 42)
      }
    }
    .padding(.vertical, 5)
  }

  private var statusSymbol: String {
    switch item.status {
    case .queued:
      "clock"
    case .analyzing:
      "waveform.path.ecg"
    case .ready:
      "checkmark.circle"
    case .converting:
      "play.circle"
    case .completed:
      "checkmark.circle.fill"
    case .failed:
      "xmark.octagon"
    case .blocked:
      "hand.raised"
    }
  }

  private var statusColor: Color {
    switch item.status {
    case .blocked, .failed:
      .red
    case .completed:
      .green
    case .converting, .analyzing:
      .blue
    case .queued, .ready:
      .secondary
    }
  }

  private var issueColor: Color {
    item.plan?.blockers.isEmpty == false ? .red : .orange
  }
}

private struct SidebarEmptyState: View {
  var body: some View {
    VStack(spacing: 8) {
      Image(systemName: "tray")
        .font(.system(size: 24, weight: .light))
        .foregroundStyle(.secondary)

      Text("No Files")
        .font(.headline)

      Text("Use the drop zone to add MKV files.")
        .font(.caption)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
    .padding()
  }
}
