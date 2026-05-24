import SwiftUI

struct PlanDetailView: View {
  let item: QueueItem?
  let presetSelection: Binding<ConversionPreset>?
  let outputName: Binding<String>?
  let resetOutputName: () -> Void
  let toolchainErrorMessage: String?

  init(
    item: QueueItem?,
    presetSelection: Binding<ConversionPreset>? = nil,
    outputName: Binding<String>? = nil,
    resetOutputName: @escaping () -> Void = {},
    toolchainErrorMessage: String? = nil
  ) {
    self.item = item
    self.presetSelection = presetSelection
    self.outputName = outputName
    self.resetOutputName = resetOutputName
    self.toolchainErrorMessage = toolchainErrorMessage
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        if let toolchainErrorMessage {
          ffmpegSetupNotice(message: toolchainErrorMessage)
        }

        if let item {
          selectedFileHeader(item)
          itemOptions(item)
          itemDetails(item)
        } else {
          VStack(alignment: .leading, spacing: 6) {
            Label("No File Selected", systemImage: "doc.text.magnifyingglass")
              .font(.headline)

            Text("Select a queued file to inspect its plan, warnings, commands, and logs.")
              .font(.callout)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          .padding(18)
          .remuxerGlassPanel(cornerRadius: 18)
        }
      }
      .padding(24)
      .frame(maxWidth: .infinity, alignment: .topLeading)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  private func selectedFileHeader(_ item: QueueItem) -> some View {
    HStack(alignment: .center, spacing: 14) {
      Image(systemName: "film")
        .font(.system(size: 28, weight: .light))
        .foregroundStyle(.secondary)
        .frame(width: 34)

      VStack(alignment: .leading, spacing: 4) {
        Text(item.fileName)
          .font(.title3.weight(.semibold))
          .lineLimit(1)

        Text(item.sourceURL.path)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .truncationMode(.middle)
      }

      Spacer()

      DetailStatusBadge(status: item.status)
    }
    .padding(18)
    .remuxerGlassPanel(cornerRadius: 18)
  }

  private func ffmpegSetupNotice(message: String) -> some View {
    DetailSection(title: "Conversion Engine") {
      Label(message, systemImage: "exclamationmark.triangle")
        .font(.caption)
        .foregroundStyle(.orange)
        .fixedSize(horizontal: false, vertical: true)
    }
  }

  @ViewBuilder
  private func itemOptions(_ item: QueueItem) -> some View {
    if let presetSelection, let outputName {
      DetailSection(title: "File Options") {
        Picker("Preset", selection: presetSelection) {
          ForEach(ConversionPreset.allCases) { preset in
            Text(preset.displayName).tag(preset)
          }
        }
        .pickerStyle(.menu)

        HStack(spacing: 8) {
          TextField(item.defaultOutputName, text: outputName)
            .textFieldStyle(.roundedBorder)

          Button("Reset") {
            resetOutputName()
          }
          .disabled(outputName.wrappedValue.isEmpty)
        }
      }
    }
  }

  @ViewBuilder
  private func itemDetails(_ item: QueueItem) -> some View {
    DetailSection(title: "Source") {
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
    VStack(alignment: .leading, spacing: 10) {
      Text(title)
        .font(.subheadline.weight(.semibold))

      VStack(alignment: .leading, spacing: 6) {
        content
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(16)
    .remuxerGlassPanel(cornerRadius: 16)
  }
}

private struct DetailStatusBadge: View {
  let status: QueueItemStatus

  var body: some View {
    Text(status.displayName)
      .font(.caption.weight(.semibold))
      .foregroundStyle(foregroundStyle)
      .padding(.horizontal, 9)
      .padding(.vertical, 5)
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
