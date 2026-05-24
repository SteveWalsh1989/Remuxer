import SwiftUI

struct PlanDetailView: View {
  let item: QueueItem?

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      header

      Divider()

      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          if let item {
            itemDetails(item)
          } else {
            VStack(alignment: .leading, spacing: 6) {
              Label("No File Selected", systemImage: "doc.text.magnifyingglass")
                .font(.headline)

              Text("Plans, warnings, blockers, commands, and logs appear here.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
          }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
      }
      .frame(maxHeight: .infinity, alignment: .top)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  private var header: some View {
    HStack {
      Label("Plan", systemImage: "sidebar.right")
        .font(.headline)

      Spacer()
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
  }

  @ViewBuilder
  private func itemDetails(_ item: QueueItem) -> some View {
    DetailSection(title: "File") {
      DetailRow(label: "Name", value: item.fileName)
      DetailRow(
        label: "Output",
        value: item.customOutputName.isEmpty ? item.defaultOutputName : item.customOutputName)
      DetailRow(label: "Preset", value: item.selectedPreset.displayName)
      DetailRow(label: "Status", value: item.status.displayName)
      DetailRow(label: "Source", value: item.sourceURL.path)
    }

    if let planningErrorMessage = item.planningErrorMessage {
      DetailSection(title: "Planning Issue") {
        Label(planningErrorMessage, systemImage: "exclamationmark.triangle")
          .font(.caption)
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }

    if let plan = item.plan {
      DetailSection(title: "Output") {
        DetailRow(label: "Mode", value: plan.mode.displayName)
        DetailRow(label: "Video", value: plan.output.videoURL.path)

        if plan.output.sidecarURLs.isEmpty == false {
          ForEach(plan.output.sidecarURLs, id: \.self) { url in
            DetailRow(label: "Sidecar", value: url.path)
          }
        }
      }

      if plan.warnings.isEmpty == false || plan.blockers.isEmpty == false {
        DetailSection(title: "Warnings And Blockers") {
          ForEach(plan.blockers) { issue in
            IssueRow(issue: issue)
          }

          ForEach(plan.warnings) { issue in
            IssueRow(issue: issue)
          }
        }
      }

      DetailSection(title: "FFmpeg Commands") {
        CommandBlock(command: plan.primaryCommand)

        ForEach(plan.subtitleExtractionCommands) { command in
          CommandBlock(command: command)
        }
      }
    }

    if item.logLines.isEmpty == false {
      DetailSection(title: "Logs") {
        Text(item.logLines.joined(separator: "\n"))
          .font(.system(.caption, design: .monospaced))
          .textSelection(.enabled)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
  }
}

private struct DetailSection<Content: View>: View {
  let title: String
  @ViewBuilder let content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.subheadline.weight(.semibold))

      VStack(alignment: .leading, spacing: 6) {
        content
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

private struct DetailRow: View {
  let label: String
  let value: String

  var body: some View {
    Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 0) {
      GridRow {
        Text(label)
          .font(.caption)
          .foregroundStyle(.secondary)
          .frame(width: 68, alignment: .leading)

        Text(value)
          .font(.caption)
          .lineLimit(2)
          .truncationMode(.middle)
          .textSelection(.enabled)
      }
    }
  }
}

private struct IssueRow: View {
  let issue: PlanIssue

  var body: some View {
    Label(
      issue.message,
      systemImage: issue.severity == .blocker ? "xmark.octagon" : "exclamationmark.triangle"
    )
    .font(.caption)
    .foregroundStyle(issue.severity == .blocker ? .red : .orange)
    .fixedSize(horizontal: false, vertical: true)
  }
}

private struct CommandBlock: View {
  let command: ProcessCommand

  var body: some View {
    Text(command.displayString)
      .font(.system(.caption, design: .monospaced))
      .textSelection(.enabled)
      .fixedSize(horizontal: false, vertical: true)
      .padding(8)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(.quaternary, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
  }
}
