import Foundation

struct FFprobeOutput: Decodable, Equatable {
  let streams: [FFprobeStream]
  let chapters: [FFprobeChapter]?
  let format: FFprobeFormat?

  func mediaFile(sourceURL: URL) -> ProbedMediaFile {
    ProbedMediaFile(
      sourceURL: sourceURL,
      formatName: format?.formatName,
      duration: format?.duration.flatMap(TimeInterval.init),
      streams: streams.map(\.mediaStream),
      chapters: (chapters ?? []).map(\.mediaChapter),
      metadata: format?.tags ?? [:]
    )
  }
}

struct FFprobeStream: Decodable, Equatable {
  let index: Int
  let codecName: String?
  let codecLongName: String?
  let codecType: String?
  let width: Int?
  let height: Int?
  let channels: Int?
  let tags: [String: String]?
  let disposition: [String: Int]?

  enum CodingKeys: String, CodingKey {
    case index
    case codecName = "codec_name"
    case codecLongName = "codec_long_name"
    case codecType = "codec_type"
    case width
    case height
    case channels
    case tags
    case disposition
  }

  var mediaStream: MediaStream {
    MediaStream(
      index: index,
      kind: MediaStreamKind(rawValue: codecType ?? "") ?? .unknown,
      codecName: codecName ?? "unknown",
      codecLongName: codecLongName,
      language: tags?["language"],
      title: tags?["title"],
      width: width,
      height: height,
      channelCount: channels,
      isAttachedPicture: disposition?["attached_pic"] == 1
    )
  }
}

struct FFprobeChapter: Decodable, Equatable {
  let id: Int
  let startTime: String?
  let endTime: String?
  let tags: [String: String]?

  enum CodingKeys: String, CodingKey {
    case id
    case startTime = "start_time"
    case endTime = "end_time"
    case tags
  }

  var mediaChapter: MediaChapter {
    MediaChapter(
      id: id,
      startTime: startTime.flatMap(TimeInterval.init) ?? 0,
      endTime: endTime.flatMap(TimeInterval.init) ?? 0,
      title: tags?["title"]
    )
  }
}

struct FFprobeFormat: Decodable, Equatable {
  let formatName: String?
  let duration: String?
  let tags: [String: String]?

  enum CodingKeys: String, CodingKey {
    case formatName = "format_name"
    case duration
    case tags
  }
}
