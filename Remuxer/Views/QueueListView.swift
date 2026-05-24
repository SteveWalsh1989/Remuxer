import SwiftUI

struct QueueListView: View {
  @ObservedObject var queue: ConversionQueue
  @Binding var selectedItemIDs: Set<QueueItem.ID>
  @Binding var isDeveloperModeEnabled: Bool

  var body: some View {
    VStack(spacing: 0) {
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

      Divider()

      Toggle(isOn: $isDeveloperModeEnabled) {
        Label("Dev Mode", systemImage: "hammer")
      }
      .toggleStyle(.switch)
      .controlSize(.small)
      .padding(.horizontal, 14)
      .padding(.vertical, 10)
      .help("Show FFmpeg commands, logs, and raw file paths for debugging.")
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
      Image(systemName: item.status.progressSymbol)
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(item.status.progressTint)
        .frame(width: 18)

      VStack(alignment: .leading, spacing: 4) {
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

        if shouldShowInlineProgress {
          ConversionProgressMeter(progress: item.progress, status: item.status, height: 4)
            .frame(width: 96)
        }
      }

      Spacer(minLength: 6)

      if item.blockingIssueMessages.isEmpty == false {
        Image(systemName: "exclamationmark.triangle.fill")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.red)
          .help(item.blockingIssueMessages.joined(separator: "\n"))
      }
    }
    .padding(.vertical, 5)
  }

  private var shouldShowInlineProgress: Bool {
    switch item.status {
    case .converting, .completed:
      true
    case .failed:
      item.progress > 0
    case .queued, .analyzing, .ready, .blocked:
      false
    }
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
