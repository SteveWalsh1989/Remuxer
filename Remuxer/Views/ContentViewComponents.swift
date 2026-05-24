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

struct IconOnlyButton: View {
  let title: String
  let systemImage: String
  let help: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Label(title, systemImage: systemImage)
    }
    .labelStyle(.iconOnly)
    .iconControlTooltip(help)
    .accessibilityLabel(Text(title))
    .accessibilityHint(Text(help))
  }
}

extension View {
  func iconControlTooltip(_ help: String) -> some View {
    modifier(IconControlTooltip(help: help))
  }
}

private struct IconControlTooltip: ViewModifier {
  let help: String

  func body(content: Content) -> some View {
    content
      .help(help)
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
