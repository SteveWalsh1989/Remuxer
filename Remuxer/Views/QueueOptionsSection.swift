import SwiftUI

struct SeriesOutputNamingPreference {
  var isEnabled = false
  var prefix = ""
  var startNumberText = "01"
  var errorMessage: String?

  var sequence: OutputNameSequence? {
    try? OutputNameSequence(prefix: prefix, startNumberText: startNumberText)
  }

  var isStartNumberInvalid: Bool {
    startNumberText.isEmpty == false
      && OutputNameSequence.isValidStartNumber(startNumberText) == false
  }
}

struct QueueOptionsSection: View {
  let targetItems: [QueueItem]
  let showsSeriesNaming: Bool
  let seriesNaming: Binding<SeriesOutputNamingPreference>
  let extractsSubtitleSidecars: Binding<Bool>
  let removesSourceAfterSuccess: Binding<Bool>
  let isWorking: Bool

  var body: some View {
    DetailSection(title: "Series Options") {
      VStack(alignment: .leading, spacing: 12) {
        if showsSeriesNaming {
          seriesNameControls
          DetailDivider()
        }

        VStack(alignment: .leading, spacing: 0) {
          if showsSeriesNaming {
            QueueOptionToggleRow(
              title: "Apply series names",
              detail: "Use the previewed names when Start is pressed.",
              systemImage: "textformat.123",
              isOn: seriesNamesBinding,
              isDisabled: canToggleSeriesNames == false
            )

            DetailDivider()
          }

          QueueOptionToggleRow(
            title: "Extract extra subtitle files",
            detail: "Create separate subtitle files only when this is checked.",
            systemImage: "captions.bubble",
            isOn: extractsSubtitleSidecars,
            isDisabled: isWorking
          )

          DetailDivider()

          QueueOptionToggleRow(
            title: "Move originals to Trash after success",
            detail: "Send source files to Trash only after successful conversions.",
            systemImage: "trash",
            tint: .red,
            isOn: removesSourceAfterSuccess,
            isDisabled: isWorking
          )
        }
      }
    }
    .onChange(of: seriesNaming.wrappedValue.prefix) { _, _ in handlePrefixChange() }
    .onChange(of: seriesNaming.wrappedValue.startNumberText) { _, _ in clearSeriesError() }
    .onChange(of: targetItemIDs) { _, _ in clearSeriesError() }
  }

  private var seriesNameControls: some View {
    HStack(alignment: .top, spacing: 14) {
      VStack(alignment: .leading, spacing: 8) {
        Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
          GridRow {
            Text("Prefix")
              .font(.caption)
              .foregroundStyle(.secondary)
              .frame(width: 82, alignment: .leading)

            TextField("PeaceMaker S02E", text: prefixBinding)
              .textFieldStyle(.roundedBorder)
          }

          GridRow {
            Text("Start")
              .font(.caption)
              .foregroundStyle(.secondary)
              .frame(width: 82, alignment: .leading)

            TextField("01", text: startNumberBinding)
              .textFieldStyle(.roundedBorder)
              .frame(maxWidth: 90)
          }
        }

        if seriesNaming.wrappedValue.isStartNumberInvalid {
          Label("Start number must use digits.", systemImage: "exclamationmark.triangle")
            .font(.caption)
            .foregroundStyle(.orange)
        }

        if let errorMessage = seriesNaming.wrappedValue.errorMessage {
          Label(errorMessage, systemImage: "exclamationmark.triangle")
            .font(.caption)
            .foregroundStyle(.red)
        }
      }
      .frame(maxWidth: 340, alignment: .leading)

      VStack(alignment: .leading, spacing: 8) {
        Text("Preview for \(targetSummary)")
          .font(.caption.weight(.medium))
          .foregroundStyle(.secondary)

        preview
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private var prefixBinding: Binding<String> {
    Binding(
      get: { seriesNaming.wrappedValue.prefix },
      set: { newValue in
        seriesNaming.wrappedValue.prefix = newValue
      }
    )
  }

  private var startNumberBinding: Binding<String> {
    Binding(
      get: { seriesNaming.wrappedValue.startNumberText },
      set: { newValue in
        seriesNaming.wrappedValue.startNumberText = newValue
      }
    )
  }

  private var seriesNamesBinding: Binding<Bool> {
    Binding(
      get: { seriesNaming.wrappedValue.isEnabled },
      set: { shouldApply in
        seriesNaming.wrappedValue.isEnabled = shouldApply
        seriesNaming.wrappedValue.errorMessage = nil
      }
    )
  }

  @ViewBuilder
  private var preview: some View {
    if previewNames.isEmpty {
      Text("No valid preview")
        .font(.caption)
        .foregroundStyle(.secondary)
    } else {
      VStack(alignment: .leading, spacing: 4) {
        ForEach(Array(previewNames.enumerated()), id: \.offset) { _, name in
          Label(name, systemImage: "doc")
            .font(.caption)
            .lineLimit(1)
        }

        if remainingPreviewCount > 0 {
          Text("+ \(remainingPreviewCount) more")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      .padding(8)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(.quaternary, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
  }

  private var previewNames: [String] {
    seriesNaming.wrappedValue.sequence?.names(count: min(targetItems.count, 5)) ?? []
  }

  private var remainingPreviewCount: Int {
    max(0, targetItems.count - previewNames.count)
  }

  private var targetSummary: String {
    targetItems.count == 1 ? "1 file" : "\(targetItems.count) files"
  }

  private var canToggleSeriesNames: Bool {
    isWorking == false
      && targetItems.isEmpty == false
      && (seriesNaming.wrappedValue.isEnabled || seriesNaming.wrappedValue.sequence != nil)
  }

  private var targetItemIDs: [QueueItem.ID] {
    targetItems.map(\.id)
  }

  private func handlePrefixChange() {
    clearSeriesError()

    if seriesNaming.wrappedValue.prefix.trimmingCharacters(in: .whitespacesAndNewlines)
      .isEmpty == false
    {
      seriesNaming.wrappedValue.isEnabled = true
    }
  }

  private func clearSeriesError() {
    seriesNaming.wrappedValue.errorMessage = nil
  }
}

private struct QueueOptionToggleRow: View {
  let title: String
  let detail: String
  let systemImage: String
  var tint: Color = .secondary
  let isOn: Binding<Bool>
  let isDisabled: Bool

  var body: some View {
    HStack(alignment: .center, spacing: 10) {
      Image(systemName: systemImage)
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(tint)
        .frame(width: 18)

      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.caption.weight(.medium))

        Text(detail)
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }

      Spacer(minLength: 12)

      Toggle("", isOn: isOn)
        .toggleStyle(.checkbox)
        .labelsHidden()
    }
    .padding(.vertical, 6)
    .disabled(isDisabled)
  }
}
