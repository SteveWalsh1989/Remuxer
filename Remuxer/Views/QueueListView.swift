import SwiftUI

struct QueueListView: View {
  @ObservedObject var queue: ConversionQueue
  @Binding var selectedItemIDs: Set<QueueItem.ID>

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

      if queue.items.isEmpty == false {
        QueueFooter(queue: queue)

        Divider()
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

private struct QueueFooter: View {
  @ObservedObject var queue: ConversionQueue

  var body: some View {
    HStack(spacing: 8) {
      Label(completedSummary, systemImage: "checkmark.circle")
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)

      Spacer(minLength: 8)

      Button {
        queue.clearCompleted()
      } label: {
        Label("Clear Completed", systemImage: "trash")
      }
      .controlSize(.small)
      .disabled(queue.canClearCompleted == false)
      .iconControlTooltip("Remove completed files from the queue.")
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 8)
  }

  private var completedSummary: String {
    queue.completedCount == 1 ? "1 completed" : "\(queue.completedCount) completed"
  }
}

private struct QueueSidebarRow: View {
  let item: QueueItem

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: item.status.progressSymbol)
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(item.status.progressTint)
        .frame(width: 18)
        .help(statusHelp)

      VStack(alignment: .leading, spacing: 4) {
        Text(item.fileName)
          .font(.body)
          .lineLimit(1)

        HStack(spacing: 5) {
          Text(item.selectedPreset.displayName)

          if showsStatusText {
            Text("·")
            Text(item.status.displayName)
          }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)

        if shouldShowInlineProgress {
          ConversionProgressMeter(progress: item.progress, status: item.status, height: 4)
            .frame(maxWidth: .infinity)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)

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

  private var showsStatusText: Bool {
    item.status != .completed
  }

  private var shouldShowInlineProgress: Bool {
    switch item.status {
    case .converting:
      true
    case .failed:
      item.progress > 0
    case .queued, .analyzing, .ready, .completed, .blocked:
      false
    }
  }

  private var statusHelp: String {
    item.status == .completed ? "Complete" : item.status.displayName
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

      Text("Use the drop zone to add MKV or MP4 files.")
        .font(.caption)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
    .padding()
  }
}
