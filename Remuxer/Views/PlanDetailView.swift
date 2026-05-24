import AppKit
import SwiftUI

struct PlanDetailView: View {
  let item: QueueItem?
  let presetSelection: Binding<ConversionPreset>?
  let outputName: Binding<String>?
  let resetOutputName: () -> Void
  let toolchainErrorMessage: String?
  let isDeveloperModeEnabled: Bool

  init(
    item: QueueItem?,
    presetSelection: Binding<ConversionPreset>? = nil,
    outputName: Binding<String>? = nil,
    resetOutputName: @escaping () -> Void = {},
    toolchainErrorMessage: String? = nil,
    isDeveloperModeEnabled: Bool = false
  ) {
    self.item = item
    self.presetSelection = presetSelection
    self.outputName = outputName
    self.resetOutputName = resetOutputName
    self.toolchainErrorMessage = toolchainErrorMessage
    self.isDeveloperModeEnabled = isDeveloperModeEnabled
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
          itemProgress(item)
          itemDetails(item)

          if isDeveloperModeEnabled {
            developerDetails(item)
          }
        } else {
          VStack(alignment: .leading, spacing: 6) {
            Label("No File Selected", systemImage: "doc.text.magnifyingglass")
              .font(.headline)

            Text("Select a queued file to inspect its progress, plan, and warnings.")
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

        Text(item.selectedPreset.displayName)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
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
  private func itemProgress(_ item: QueueItem) -> some View {
    switch item.status {
    case .analyzing:
      DetailSection(title: "Progress") {
        HStack(spacing: 10) {
          ProgressView()
            .controlSize(.small)

          Text("Analyzing file")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
    case .converting, .completed:
      let progress = boundedProgress(item.progress)

      DetailSection(title: "Progress") {
        HStack(spacing: 10) {
          ProgressView(value: progress)
            .frame(maxWidth: 360)

          Text(progressPercentage(progress))
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
            .frame(width: 42, alignment: .trailing)
        }

        Text(item.status == .completed ? "Complete" : "Converting file")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    case .failed where item.progress > 0:
      let progress = boundedProgress(item.progress)

      DetailSection(title: "Progress") {
        HStack(spacing: 10) {
          ProgressView(value: progress)
            .frame(maxWidth: 360)

          Text(progressPercentage(progress))
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
            .frame(width: 42, alignment: .trailing)
        }

        Text("Stopped before completion")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    default:
      EmptyView()
    }
  }

  @ViewBuilder
  private func itemDetails(_ item: QueueItem) -> some View {
    DetailSection(title: "File") {
      DetailRow(
        label: "Output",
        value: item.customOutputName.isEmpty ? item.defaultOutputName : item.customOutputName)
      DetailRow(label: "Preset", value: item.selectedPreset.displayName)
      DetailRow(label: "Status", value: item.status.displayName)
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
        DetailRow(label: "Video", value: plan.output.videoURL.lastPathComponent)

        if plan.output.sidecarURLs.isEmpty == false {
          ForEach(plan.output.sidecarURLs, id: \.self) { url in
            DetailRow(label: "Sidecar", value: url.lastPathComponent)
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
    }
  }

  @ViewBuilder
  private func developerDetails(_ item: QueueItem) -> some View {
    DetailSection(
      title: "Developer Details",
      copyText: developerDetailsText(for: item),
      copyHelp: "Copy raw file paths and planning details."
    ) {
      DetailRow(label: "Source", value: item.sourceURL.path)

      if let plan = item.plan {
        DetailRow(label: "Output", value: plan.output.videoURL.path)

        ForEach(plan.output.sidecarURLs, id: \.self) { url in
          DetailRow(label: "Sidecar", value: url.path)
        }
      }
    }

    if let plan = item.plan {
      DetailSection(
        title: "FFmpeg Commands",
        copyText: commandsText(for: plan),
        copyHelp: "Copy FFmpeg commands."
      ) {
        CommandBlock(command: plan.primaryCommand)

        ForEach(plan.subtitleExtractionCommands) { command in
          CommandBlock(command: command)
        }
      }
    }

    if item.logLines.isEmpty == false {
      DetailSection(
        title: "Logs",
        copyText: logsText(for: item),
        copyHelp: "Copy conversion logs."
      ) {
        Text(logsText(for: item))
          .font(.system(.caption, design: .monospaced))
          .textSelection(.enabled)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
  }

  private func boundedProgress(_ progress: Double) -> Double {
    min(max(progress, 0), 1)
  }

  private func progressPercentage(_ progress: Double) -> String {
    "\(Int((progress * 100).rounded()))%"
  }

  private func developerDetailsText(for item: QueueItem) -> String {
    var lines = [
      "Source: \(item.sourceURL.path)",
      "Preset: \(item.selectedPreset.displayName)",
      "Status: \(item.status.displayName)",
    ]

    if let plan = item.plan {
      lines.append("Output: \(plan.output.videoURL.path)")
      lines.append(contentsOf: plan.output.sidecarURLs.map { "Sidecar: \($0.path)" })
    }

    if let planningErrorMessage = item.planningErrorMessage {
      lines.append("Planning issue: \(planningErrorMessage)")
    }

    return lines.joined(separator: "\n")
  }

  private func commandsText(for plan: ConversionPlan) -> String {
    ([plan.primaryCommand] + plan.subtitleExtractionCommands)
      .map(\.displayString)
      .joined(separator: "\n")
  }

  private func logsText(for item: QueueItem) -> String {
    item.logLines.joined(separator: "\n")
  }
}

private struct DetailSection<Content: View>: View {
  let title: String
  let copyText: String?
  let copyHelp: String
  private let content: Content

  init(
    title: String,
    copyText: String? = nil,
    copyHelp: String = "Copy section contents.",
    @ViewBuilder content: () -> Content
  ) {
    self.title = title
    self.copyText = copyText
    self.copyHelp = copyHelp
    self.content = content()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 8) {
        Text(title)
          .font(.subheadline.weight(.semibold))

        Spacer()

        if let copyText, copyText.isEmpty == false {
          CopyToClipboardButton(text: copyText, help: copyHelp)
        }
      }

      VStack(alignment: .leading, spacing: 6) {
        content
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(16)
    .remuxerGlassPanel(cornerRadius: 16)
  }
}

private struct CopyToClipboardButton: View {
  let text: String
  let help: String

  var body: some View {
    Button {
      let pasteboard = NSPasteboard.general
      pasteboard.clearContents()
      pasteboard.setString(text, forType: .string)
    } label: {
      Label("Copy", systemImage: "doc.on.doc")
    }
    .labelStyle(.iconOnly)
    .buttonStyle(.borderless)
    .help(help)
    .accessibilityLabel(Text(help))
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
