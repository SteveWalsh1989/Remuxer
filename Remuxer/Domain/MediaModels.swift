import Foundation

enum MediaStreamKind: String, Codable {
  case video
  case audio
  case subtitle
  case attachment
  case data
  case unknown
}

struct MediaStream: Codable, Equatable, Identifiable {
  let index: Int
  let kind: MediaStreamKind
  let codecName: String
  let codecLongName: String?
  let language: String?
  let title: String?
  let width: Int?
  let height: Int?
  let channelCount: Int?

  var id: Int { index }

  var displayName: String {
    var parts = ["#\(index)", codecName]

    if let language, language.isEmpty == false {
      parts.append(language)
    }

    if let title, title.isEmpty == false {
      parts.append(title)
    }

    return parts.joined(separator: " - ")
  }
}

struct MediaChapter: Codable, Equatable, Identifiable {
  let id: Int
  let startTime: TimeInterval
  let endTime: TimeInterval
  let title: String?
}

struct ProbedMediaFile: Codable, Equatable {
  let sourceURL: URL
  let formatName: String?
  let duration: TimeInterval?
  let streams: [MediaStream]
  let chapters: [MediaChapter]
  let metadata: [String: String]

  var videoStreams: [MediaStream] {
    streams.filter { $0.kind == .video }
  }

  var audioStreams: [MediaStream] {
    streams.filter { $0.kind == .audio }
  }

  var subtitleStreams: [MediaStream] {
    streams.filter { $0.kind == .subtitle }
  }

  var attachmentStreams: [MediaStream] {
    streams.filter { $0.kind == .attachment }
  }
}
