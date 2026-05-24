import Foundation

enum ConversionPreset: String, CaseIterable, Codable, Identifiable {
  case losslessMP4
  case appleHEVC
  case universalMP4
  case archive

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .losslessMP4:
      "Lossless MP4"
    case .appleHEVC:
      "Apple HEVC"
    case .universalMP4:
      "Universal MP4"
    case .archive:
      "Archive"
    }
  }

  var outputExtension: String {
    switch self {
    case .losslessMP4, .appleHEVC, .universalMP4:
      "mp4"
    case .archive:
      "mkv"
    }
  }

  var planningMode: PlanMode {
    switch self {
    case .losslessMP4:
      .remux
    case .appleHEVC, .universalMP4:
      .transcode
    case .archive:
      .archive
    }
  }

  var summary: String {
    switch self {
    case .losslessMP4:
      "Copy compatible streams into MP4. Blocks instead of re-encoding."
    case .appleHEVC:
      "Transcode video to HEVC for Apple devices using hardware encoding."
    case .universalMP4:
      "Transcode video to H.264 for broad playback compatibility."
    case .archive:
      "Keep MKV and copy original streams for preservation."
    }
  }

  var isTranscode: Bool {
    planningMode == .transcode
  }
}
