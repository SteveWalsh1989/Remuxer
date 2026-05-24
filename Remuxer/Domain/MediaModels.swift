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
  let isAttachedPicture: Bool

  enum CodingKeys: String, CodingKey {
    case index
    case kind
    case codecName
    case codecLongName
    case language
    case title
    case width
    case height
    case channelCount
    case isAttachedPicture
  }

  init(
    index: Int,
    kind: MediaStreamKind,
    codecName: String,
    codecLongName: String?,
    language: String?,
    title: String?,
    width: Int?,
    height: Int?,
    channelCount: Int?,
    isAttachedPicture: Bool = false
  ) {
    self.index = index
    self.kind = kind
    self.codecName = codecName
    self.codecLongName = codecLongName
    self.language = language
    self.title = title
    self.width = width
    self.height = height
    self.channelCount = channelCount
    self.isAttachedPicture = isAttachedPicture
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    index = try container.decode(Int.self, forKey: .index)
    kind = try container.decode(MediaStreamKind.self, forKey: .kind)
    codecName = try container.decode(String.self, forKey: .codecName)
    codecLongName = try container.decodeIfPresent(String.self, forKey: .codecLongName)
    language = try container.decodeIfPresent(String.self, forKey: .language)
    title = try container.decodeIfPresent(String.self, forKey: .title)
    width = try container.decodeIfPresent(Int.self, forKey: .width)
    height = try container.decodeIfPresent(Int.self, forKey: .height)
    channelCount = try container.decodeIfPresent(Int.self, forKey: .channelCount)
    isAttachedPicture =
      try container.decodeIfPresent(Bool.self, forKey: .isAttachedPicture) ?? false
  }

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
    streams.filter { $0.kind == .video && $0.isAttachedPicture == false }
  }

  var audioStreams: [MediaStream] {
    streams.filter { $0.kind == .audio }
  }

  var subtitleStreams: [MediaStream] {
    streams.filter { $0.kind == .subtitle }
  }

  var attachmentStreams: [MediaStream] {
    streams.filter { $0.kind == .attachment || $0.isAttachedPicture }
  }
}
