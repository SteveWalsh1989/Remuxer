import XCTest

@testable import Remuxer

final class FFprobeDecodingTests: XCTestCase {
  func testDecodesStreamsChaptersAndFormatMetadata() throws {
    let json = """
      {
        "streams": [
          {
            "index": 0,
            "codec_name": "h264",
            "codec_long_name": "H.264 / AVC",
            "codec_type": "video",
            "width": 1920,
            "height": 1080,
            "tags": { "language": "eng", "title": "Main" }
          },
          {
            "index": 1,
            "codec_name": "flac",
            "codec_type": "audio",
            "channels": 2,
            "tags": { "language": "jpn" }
          },
          {
            "index": 2,
            "codec_name": "subrip",
            "codec_type": "subtitle",
            "tags": { "language": "eng" }
          }
        ],
        "chapters": [
          {
            "id": 0,
            "start_time": "0.000000",
            "end_time": "60.000000",
            "tags": { "title": "Opening" }
          }
        ],
        "format": {
          "format_name": "matroska,webm",
          "duration": "120.500000",
          "tags": { "title": "Fixture" }
        }
      }
      """

    let output = try JSONDecoder().decode(FFprobeOutput.self, from: Data(json.utf8))
    let media = output.mediaFile(sourceURL: URL(fileURLWithPath: "/Movies/Fixture.mkv"))

    XCTAssertEqual(media.formatName, "matroska,webm")
    XCTAssertEqual(media.duration, 120.5)
    XCTAssertEqual(media.videoStreams.first?.codecName, "h264")
    XCTAssertEqual(media.audioStreams.first?.codecName, "flac")
    XCTAssertEqual(media.subtitleStreams.first?.language, "eng")
    XCTAssertEqual(media.chapters.first?.title, "Opening")
    XCTAssertEqual(media.metadata["title"], "Fixture")
  }
}
