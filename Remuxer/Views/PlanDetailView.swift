import AppKit
import SwiftUI

struct PlanDetailView: View {
  let item: QueueItem?
  let presetSelection: Binding<ConversionPreset>?
  let outputName: Binding<String>?
  let resetOutputName: () -> Void
  let toolchainErrorMessage: String?
  let removesSourceAfterSuccess: Bool
  let isDeveloperModeEnabled: Bool

  init(
    item: QueueItem?,
    presetSelection: Binding<ConversionPreset>? = nil,
    outputName: Binding<String>? = nil,
    resetOutputName: @escaping () -> Void = {},
    toolchainErrorMessage: String? = nil,
    removesSourceAfterSuccess: Bool = false,
    isDeveloperModeEnabled: Bool = false
  ) {
    self.item = item
    self.presetSelection = presetSelection
    self.outputName = outputName
    self.resetOutputName = resetOutputName
    self.toolchainErrorMessage = toolchainErrorMessage
    self.removesSourceAfterSuccess = removesSourceAfterSuccess
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

            Text("Select a queued file to inspect its progress, output, and planning notes.")
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

        HStack(spacing: 6) {
          Text(item.selectedPreset.displayName)
          Text("·")
          Text(item.streamSummary)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
      }

      Spacer()

      if removesSourceAfterSuccess {
        Image(systemName: "trash")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.red)
          .help("The original file will be removed after a successful conversion.")
      }

      if let plan = item.plan {
        IssueSummaryBadges(blockers: plan.blockers, warnings: plan.warnings, compact: true)
      }

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
        HStack(spacing: 9) {
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
        ProgressSummary(
          status: item.status,
          progress: progress,
          message: item.status == .completed ? "Complete" : "Converting file"
        )
      }
    case .failed where item.progress > 0:
      let progress = boundedProgress(item.progress)

      DetailSection(title: "Progress") {
        ProgressSummary(
          status: item.status, progress: progress, message: "Stopped before completion")
      }
    default:
      EmptyView()
    }
  }

  @ViewBuilder
  private func itemDetails(_ item: QueueItem) -> some View {
    if let planningErrorMessage = item.planningErrorMessage {
      DetailSection(title: "Needs Attention") {
        Label(planningErrorMessage, systemImage: "exclamationmark.triangle")
          .font(.caption)
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
    }

    if let plan = item.plan {
      DetailSection(title: "Output") {
        DetailRow(label: "Video", value: plan.output.videoURL.lastPathComponent)
        DetailRow(
          label: "Folder", value: displayPath(plan.output.videoURL.deletingLastPathComponent()))
        DetailRow(label: "Mode", value: plan.mode.displayName)

        if plan.output.sidecarURLs.isEmpty == false {
          DetailDivider()

          ForEach(plan.output.sidecarURLs, id: \.self) { sidecarURL in
            DetailRow(label: "Sidecar", value: sidecarURL.lastPathComponent)
          }
        }

        if removesSourceAfterSuccess {
          DetailDivider()

          Label("Original will be removed after successful conversion.", systemImage: "trash")
            .font(.caption)
            .foregroundStyle(.red)
        }
      }

      if plan.warnings.isEmpty == false || plan.blockers.isEmpty == false {
        DetailSection(title: "Checks") {
          IssueSummaryBadges(blockers: plan.blockers, warnings: plan.warnings)
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

  private func displayPath(_ url: URL) -> String {
    let homePath = FileManager.default.homeDirectoryForCurrentUser.path
    guard url.path.hasPrefix(homePath) else {
      return url.path
    }

    return "~" + String(url.path.dropFirst(homePath.count))
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
