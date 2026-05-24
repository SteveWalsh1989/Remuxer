import XCTest

@testable import Remuxer

final class CompatibilityRulesTests: XCTestCase {
  func testClassifiesMP4CopyCompatibleStreams() {
    XCTAssertTrue(
      StreamCompatibilityRules.canCopyVideoToMP4(stream(codecName: "h264", kind: .video)))
    XCTAssertTrue(
      StreamCompatibilityRules.canCopyAudioToMP4(stream(codecName: "aac", kind: .audio)))
    XCTAssertTrue(
      StreamCompatibilityRules.canCopySubtitleToMP4(stream(codecName: "mov_text", kind: .subtitle)))
  }

  func testClassifiesIncompatibleStreams() {
    XCTAssertFalse(
      StreamCompatibilityRules.canCopyVideoToMP4(stream(codecName: "vp9", kind: .video)))
    XCTAssertFalse(
      StreamCompatibilityRules.canCopyAudioToMP4(stream(codecName: "flac", kind: .audio)))
    XCTAssertFalse(
      StreamCompatibilityRules.canCopySubtitleToMP4(stream(codecName: "subrip", kind: .subtitle)))
  }

  func testSubtitleSidecarExtensionMatchesCodec() {
    XCTAssertEqual(
      StreamCompatibilityRules.sidecarExtension(for: stream(codecName: "subrip", kind: .subtitle)),
      "srt"
    )
    XCTAssertEqual(
      StreamCompatibilityRules.sidecarExtension(
        for: stream(codecName: "hdmv_pgs_subtitle", kind: .subtitle)),
      "sup"
    )
  }

  private func stream(codecName: String, kind: MediaStreamKind) -> MediaStream {
    MediaStream(
      index: 0,
      kind: kind,
      codecName: codecName,
      codecLongName: nil,
      language: nil,
      title: nil,
      width: nil,
      height: nil,
      channelCount: nil
    )
  }
}
