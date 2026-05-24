import Foundation
import SwiftUI

extension ContentView {
  var rememberedSourceFolderURL: URL? {
    guard lastSourceFolderPath.isEmpty == false else {
      return nil
    }

    let url = URL(fileURLWithPath: lastSourceFolderPath)
    return FileManager.default.directoryExists(at: url) ? url : nil
  }

  func rememberSourceFolder(from urls: [URL]) {
    guard let sourceFolderURL = urls.first?.deletingLastPathComponent() else {
      return
    }

    lastSourceFolderPath = sourceFolderURL.path
  }
}

struct EmptyQueueDropZone: View {
  let isDropTargeted: Bool
  let addFiles: () -> Void

  var body: some View {
    ZStack {
      VStack(spacing: 22) {
        Image(systemName: "film.stack")
          .font(.system(size: 50, weight: .light))
          .foregroundStyle(isDropTargeted ? Color.accentColor : Color.secondary)

        VStack(spacing: 7) {
          Text("Drop MKV files here")
            .font(.title2.weight(.semibold))

          Text("Add a batch, inspect the generated plans, then convert when everything is clear.")
            .font(.callout)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 430)
        }

        Button {
          addFiles()
        } label: {
          Label("Add MKV Files...", systemImage: "plus")
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .keyboardShortcut("o", modifiers: .command)
        .help("Add MKV files to the conversion queue.")
      }
      .padding(44)
      .frame(maxWidth: 620)
      .remuxerGlassPanel(cornerRadius: 28)
      .overlay {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
          .strokeBorder(
            isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.22),
            style: StrokeStyle(lineWidth: isDropTargeted ? 2 : 1, dash: [8, 7])
          )
          .allowsHitTesting(false)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(32)
  }
}

struct OutputNameSequenceSheet: View {
  let targetItems: [QueueItem]
  let isWorking: Bool
  let apply: (String, String) throws -> Void

  @Environment(\.dismiss) private var dismiss
  @State private var prefix = ""
  @State private var startNumberText = "01"
  @State private var errorMessage: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      VStack(alignment: .leading, spacing: 4) {
        Text("Batch Rename")
          .font(.headline)

        Text(targetSummary)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      VStack(alignment: .leading, spacing: 10) {
        TextField("Prefix", text: $prefix)
          .textFieldStyle(.roundedBorder)

        TextField("Start Number", text: $startNumberText)
          .textFieldStyle(.roundedBorder)

        if isStartNumberInvalid {
          Label("Start number must use digits.", systemImage: "exclamationmark.triangle")
            .font(.caption)
            .foregroundStyle(.orange)
        }
      }

      VStack(alignment: .leading, spacing: 8) {
        Text("Preview")
          .font(.subheadline.weight(.semibold))

        VStack(alignment: .leading, spacing: 6) {
          if previewNames.isEmpty {
            Text("No valid preview")
              .font(.caption)
              .foregroundStyle(.secondary)
          } else {
            ForEach(Array(previewNames.enumerated()), id: \.offset) { _, name in
              HStack(spacing: 8) {
                Image(systemName: "doc")
                  .foregroundStyle(.secondary)
                  .frame(width: 14)

                Text(name)
                  .font(.caption)
                  .lineLimit(1)

                Spacer()
              }
            }

            if remainingPreviewCount > 0 {
              Text("+ \(remainingPreviewCount) more")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
      }

      if let errorMessage {
        Label(errorMessage, systemImage: "exclamationmark.triangle")
          .font(.caption)
          .foregroundStyle(.red)
      }

      HStack {
        Spacer()

        Button("Cancel") {
          dismiss()
        }
        .keyboardShortcut(.cancelAction)

        Button {
          applySequence()
        } label: {
          Label("Apply", systemImage: "checkmark")
        }
        .keyboardShortcut(.defaultAction)
        .disabled(canApply == false)
      }
    }
    .padding(20)
    .frame(width: 420)
    .onChange(of: prefix) { _, _ in errorMessage = nil }
    .onChange(of: startNumberText) { _, _ in errorMessage = nil }
  }

  private var targetSummary: String {
    targetItems.count == 1 ? "1 file" : "\(targetItems.count) files"
  }

  private var sequence: OutputNameSequence? {
    try? OutputNameSequence(prefix: prefix, startNumberText: startNumberText)
  }

  private var previewNames: [String] {
    sequence?.names(count: min(targetItems.count, 5)) ?? []
  }

  private var remainingPreviewCount: Int {
    max(0, targetItems.count - previewNames.count)
  }

  private var canApply: Bool {
    isWorking == false && targetItems.isEmpty == false && sequence != nil
  }

  private var isStartNumberInvalid: Bool {
    startNumberText.isEmpty == false
      && OutputNameSequence.isValidStartNumber(startNumberText) == false
  }

  private func applySequence() {
    do {
      try apply(prefix, startNumberText)
      dismiss()
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}

private struct RemuxerGlassPanel: ViewModifier {
  let cornerRadius: CGFloat

  func body(content: Content) -> some View {
    if #available(macOS 26.0, *) {
      content
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    } else {
      content
        .background(
          .regularMaterial,
          in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
    }
  }
}

extension View {
  func remuxerGlassPanel(cornerRadius: CGFloat) -> some View {
    modifier(RemuxerGlassPanel(cornerRadius: cornerRadius))
  }
}

func droppedURL(from item: NSSecureCoding?) -> URL? {
  if let url = item as? URL {
    return url
  }

  if let data = item as? Data {
    return URL(dataRepresentation: data, relativeTo: nil)
  }

  return nil
}

extension FileManager {
  func directoryExists(at url: URL) -> Bool {
    var isDirectory: ObjCBool = false
    let exists = fileExists(atPath: url.path, isDirectory: &isDirectory)
    return exists && isDirectory.boolValue
  }
}
