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

private struct IssuePill: View {
  let title: String
  let count: Int
  let systemImage: String
  let tint: Color
  let messages: [String]
  let compact: Bool

  var body: some View {
    Label(labelText, systemImage: systemImage)
      .font(.caption.weight(.semibold))
      .labelStyle(.titleAndIcon)
      .foregroundStyle(tint)
      .padding(.horizontal, compact ? 6 : 9)
      .padding(.vertical, compact ? 4 : 5)
      .background(tint.opacity(0.12), in: Capsule())
      .help(messages.joined(separator: "\n"))
      .accessibilityLabel(Text("\(labelText): \(messages.joined(separator: ", "))"))
  }

  private var labelText: String {
    guard compact == false else {
      return "\(count)"
    }

    return "\(count) \(title)\(count == 1 ? "" : "s")"
  }
}
