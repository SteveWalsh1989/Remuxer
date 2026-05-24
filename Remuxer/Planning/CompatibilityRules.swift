import Foundation

enum StreamCompatibilityRules {
  static let mp4CopyVideoCodecs: Set<String> = [
    "h264",
    "avc1",
    "hevc",
    "h265",
    "mpeg4",
  ]

  static let mp4CopyAudioCodecs: Set<String> = [
    "aac",
    "alac",
    "mp3",
    "ac3",
    "eac3",
  ]

  static let mp4CopySubtitleCodecs: Set<String> = [
    "mov_text",
    "tx3g",
  ]

  static func canCopyVideoToMP4(_ stream: MediaStream) -> Bool {
    mp4CopyVideoCodecs.contains(normalizedCodecName(stream.codecName))
  }

  static func canCopyAudioToMP4(_ stream: MediaStream) -> Bool {
    mp4CopyAudioCodecs.contains(normalizedCodecName(stream.codecName))
  }

  static func canCopySubtitleToMP4(_ stream: MediaStream) -> Bool {
    mp4CopySubtitleCodecs.contains(normalizedCodecName(stream.codecName))
  }

  static func sidecarExtension(for stream: MediaStream) -> String {
    switch normalizedCodecName(stream.codecName) {
    case "subrip", "srt":
      "srt"
    case "ass":
      "ass"
    case "ssa":
      "ssa"
    case "webvtt":
      "vtt"
    case "hdmv_pgs_subtitle", "pgs":
      "sup"
    default:
      "sub"
    }
  }

  private static func normalizedCodecName(_ codecName: String) -> String {
    codecName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
  }
}
