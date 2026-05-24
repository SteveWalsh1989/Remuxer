import AppKit
import SwiftUI

struct DetailSection<Content: View>: View {
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

struct DetailStatusBadge: View {
  let status: QueueItemStatus

  var body: some View {
    Text(status.displayName)
      .font(.caption.weight(.semibold))
      .foregroundStyle(foregroundStyle)
      .padding(.horizontal, 9)
      .padding(.vertical, 5)
      .background(foregroundStyle.opacity(0.14), in: Capsule())
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
}

struct ProgressSummary: View {
  let status: QueueItemStatus
  let progress: Double
  let message: String

  var body: some View {
    VStack(alignment: .leading, spacing: 9) {
      HStack(spacing: 8) {
        Label(message, systemImage: status.progressSymbol)
          .font(.caption.weight(.medium))
          .foregroundStyle(status.progressTint)

        Spacer()

        Text(progressPercentage)
          .font(.caption.monospacedDigit().weight(.medium))
          .foregroundStyle(.secondary)
      }

      ConversionProgressMeter(progress: progress, status: status, height: 8)
        .frame(maxWidth: 420)
    }
  }

  private var progressPercentage: String {
    "\(Int((min(max(progress, 0), 1) * 100).rounded()))%"
  }
}

struct FileProgressStrip: View {
  let status: QueueItemStatus
  let progress: Double
  var label = "Converting"

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      HStack(spacing: 8) {
        Label(label, systemImage: status.progressSymbol)
          .font(.caption.weight(.medium))
          .foregroundStyle(status.progressTint)

        Spacer()

        Text(progressPercentage)
          .font(.caption.monospacedDigit().weight(.medium))
          .foregroundStyle(.secondary)
      }

      ConversionProgressMeter(progress: progress, status: status, height: 6)
    }
    .padding(.leading, 48)
  }

  private var progressPercentage: String {
    "\(Int((min(max(progress, 0), 1) * 100).rounded()))%"
  }
}

struct ConversionProgressMeter: View {
  let progress: Double
  let status: QueueItemStatus
  let height: CGFloat

  init(progress: Double, status: QueueItemStatus, height: CGFloat = 6) {
    self.progress = progress
    self.status = status
    self.height = height
  }

  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
        Capsule()
          .fill(Color.secondary.opacity(0.16))

        if boundedProgress > 0 {
          Capsule()
            .fill(status.progressTint.gradient)
            .frame(width: max(height, geometry.size.width * boundedProgress))
        }
      }
    }
    .frame(height: height)
    .animation(.smooth(duration: 0.2), value: boundedProgress)
    .accessibilityLabel(Text("Progress"))
    .accessibilityValue(Text("\(Int((boundedProgress * 100).rounded())) percent"))
  }

  private var boundedProgress: Double {
    min(max(progress, 0), 1)
  }
}

struct OutputSummaryContent: View {
  let videoFileName: String
  let folder: String
  let mode: String
  let sidecarFileNames: [String]

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      OutputInfoRow(
        systemImage: "film",
        title: videoFileName,
        subtitle: folder,
        accessory: mode
      )

      if sidecarFileNames.isEmpty == false {
        DetailDivider()

        ForEach(sidecarFileNames, id: \.self) { fileName in
          OutputInfoRow(
            systemImage: "captions.bubble",
            title: fileName,
            subtitle: "Subtitle sidecar"
          )
        }
      }
    }
  }
}

private struct OutputInfoRow: View {
  let systemImage: String
  let title: String
  let subtitle: String
  var accessory: String?
  var tint: Color = .secondary

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(systemName: systemImage)
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(tint)
        .frame(width: 18)

      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.caption.weight(.medium))
          .lineLimit(1)
          .truncationMode(.middle)
          .textSelection(.enabled)

        Text(subtitle)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(2)
          .truncationMode(.middle)
          .textSelection(.enabled)
      }

      Spacer(minLength: 10)

      if let accessory {
        Text(accessory)
          .font(.caption.weight(.medium))
          .foregroundStyle(.secondary)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(.quaternary, in: Capsule())
      }
    }
  }
}

struct DetailRow: View {
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

struct DetailDivider: View {
  var body: some View {
    Divider()
      .padding(.vertical, 2)
  }
}

struct IssueSummaryBadges: View {
  let blockers: [PlanIssue]
  let warnings: [PlanIssue]
  var compact = false

  var body: some View {
    HStack(spacing: 8) {
      if blockers.isEmpty == false {
        IssuePill(
          title: "Blocked",
          count: blockers.count,
          systemImage: "xmark.octagon.fill",
          tint: .red,
          messages: blockers.map(\.message),
          compact: compact
        )
      }

      if warnings.isEmpty == false {
        IssuePill(
          title: "Warning",
          count: warnings.count,
          systemImage: "exclamationmark.triangle.fill",
          tint: .orange,
          messages: warnings.map(\.message),
          compact: compact
        )
      }
    }
  }
}

struct CommandBlock: View {
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

extension QueueItemStatus {
  var progressSymbol: String {
    switch self {
    case .queued:
      "clock"
    case .analyzing:
      "waveform.path.ecg"
    case .ready:
      "checkmark.circle"
    case .converting:
      "play.circle.fill"
    case .completed:
      "checkmark.circle.fill"
    case .failed:
      "xmark.octagon.fill"
    case .blocked:
      "hand.raised.fill"
    }
  }

  var progressTint: Color {
    switch self {
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
}

private struct CopyToClipboardButton: View {
  let text: String
  let help: String

  var body: some View {
    IconOnlyButton(
      title: "Copy",
      systemImage: "doc.on.doc",
      help: help
    ) {
      let pasteboard = NSPasteboard.general
      pasteboard.clearContents()
      pasteboard.setString(text, forType: .string)
    }
    .buttonStyle(.borderless)
  }
}

private struct IssuePill: View {
  let title: String
  let count: Int
  let systemImage: String
  let tint: Color
  let messages: [String]
  let compact: Bool

  @State private var isPopoverPresented = false

  var body: some View {
    Button {
      isPopoverPresented = true
    } label: {
      Label(labelText, systemImage: systemImage)
    }
    .buttonStyle(.plain)
    .font(.caption.weight(.semibold))
    .labelStyle(.titleAndIcon)
    .foregroundStyle(tint)
    .padding(.horizontal, compact ? 6 : 9)
    .padding(.vertical, compact ? 4 : 5)
    .background(tint.opacity(0.12), in: Capsule())
    .contentShape(Capsule())
    .onHover { isHovering in
      isPopoverPresented = isHovering
    }
    .overlay(alignment: .topTrailing) {
      if isPopoverPresented {
        IssuePopoverContent(
          title: summaryText,
          systemImage: systemImage,
          tint: tint,
          messages: messages
        )
        .offset(y: 24)
        .allowsHitTesting(false)
        .zIndex(20)
      }
    }
    .accessibilityLabel(Text("\(summaryText): \(messages.joined(separator: ", "))"))
    .accessibilityHint(Text("Hover or click to review each issue."))
  }

  private var labelText: String {
    guard compact == false else {
      return "\(count)"
    }

    return summaryText
  }

  private var summaryText: String {
    switch title {
    case "Blocked":
      count == 1 ? "1 Blocked issue" : "\(count) Blocked issues"
    case "Warning":
      count == 1 ? "1 Warning" : "\(count) Warnings"
    default:
      "\(count) \(title)\(count == 1 ? "" : "s")"
    }
  }
}

private struct IssuePopoverContent: View {
  let title: String
  let systemImage: String
  let tint: Color
  let messages: [String]

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Label(title, systemImage: systemImage)
        .font(.caption.weight(.semibold))
        .foregroundStyle(tint)

      ScrollView {
        VStack(alignment: .leading, spacing: 8) {
          ForEach(Array(messages.enumerated()), id: \.offset) { offset, message in
            HStack(alignment: .firstTextBaseline, spacing: 8) {
              Text("\(offset + 1).")
                .font(.caption.monospacedDigit().weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 22, alignment: .trailing)

              Text(message)
                .font(.caption)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
            }
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .frame(maxHeight: 240)
    }
    .padding(12)
    .frame(width: 340, alignment: .leading)
    .background(
      .regularMaterial,
      in: RoundedRectangle(cornerRadius: 10, style: .continuous)
    )
    .overlay {
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .strokeBorder(Color.secondary.opacity(0.18))
    }
    .shadow(color: .black.opacity(0.2), radius: 14, y: 6)
  }
}
