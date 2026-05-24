import XCTest

@testable import Remuxer

final class ConversionPlannerTests: XCTestCase {
  func testLosslessMP4CopiesCompatibleStreamsAndExtractsSubtitles() throws {
    let planner = ConversionPlanner(
      outputPathResolver: OutputPathResolver(fileChecker: EmptyFileChecker()))
    let plan = try planner.makePlan(
      for: media(audioCodec: "aac", subtitleCodec: "subrip"),
      preset: .losslessMP4,
      outputOptions: OutputOptions()
    )

    XCTAssertEqual(plan.mode, .remux)
    XCTAssertTrue(plan.canExecute)
    XCTAssertTrue(plan.primaryCommand.arguments.contains("-c"))
    XCTAssertTrue(plan.primaryCommand.arguments.contains("copy"))
    XCTAssertEqual(plan.subtitleExtractionCommands.count, 1)
    XCTAssertEqual(plan.output.videoURL.lastPathComponent, "Movie.mp4")
    XCTAssertEqual(plan.output.sidecarURLs.first?.lastPathComponent, "Movie.2.eng.srt")
  }

  func testLosslessMP4BlocksVideoReEncodingAndAudioTranscoding() throws {
    let planner = ConversionPlanner(
      outputPathResolver: OutputPathResolver(fileChecker: EmptyFileChecker()))
    let plan = try planner.makePlan(
      for: media(videoCodec: "vp9", audioCodec: "flac", subtitleCodec: nil),
      preset: .losslessMP4,
      outputOptions: OutputOptions()
    )

    XCTAssertFalse(plan.canExecute)
    XCTAssertEqual(plan.blockers.count, 2)
  }

  func testAppleHEVCUsesHardwareEncoderAndWarnsForAudioConversion() throws {
    let planner = ConversionPlanner(
      outputPathResolver: OutputPathResolver(fileChecker: EmptyFileChecker()))
    let plan = try planner.makePlan(
      for: media(audioCodec: "flac", subtitleCodec: "ass"),
      preset: .appleHEVC,
      outputOptions: OutputOptions()
    )

    XCTAssertEqual(plan.mode, .transcode)
    XCTAssertTrue(plan.canExecute)
    XCTAssertTrue(plan.primaryCommand.arguments.contains("hevc_videotoolbox"))
    XCTAssertTrue(plan.primaryCommand.arguments.contains("aac"))
    XCTAssertEqual(plan.subtitleExtractionCommands.count, 1)
    XCTAssertEqual(plan.warnings.count, 2)
  }

  func testUniversalMP4UsesH264Encoder() throws {
    let planner = ConversionPlanner(
      outputPathResolver: OutputPathResolver(fileChecker: EmptyFileChecker()))
    let plan = try planner.makePlan(
      for: media(audioCodec: "aac", subtitleCodec: nil),
      preset: .universalMP4,
      outputOptions: OutputOptions()
    )

    XCTAssertTrue(plan.primaryCommand.arguments.contains("libx264"))
    XCTAssertTrue(plan.primaryCommand.arguments.contains("18"))
  }

  func testCustomOutputNameAppliesToVideoAndSidecars() throws {
    let planner = ConversionPlanner(
      outputPathResolver: OutputPathResolver(fileChecker: EmptyFileChecker()))
    let plan = try planner.makePlan(
      for: media(audioCodec: "aac", subtitleCodec: "subrip"),
      preset: .losslessMP4,
      outputOptions: OutputOptions(),
      customOutputName: "Custom Movie"
    )

    XCTAssertEqual(plan.output.videoURL.lastPathComponent, "Custom Movie.mp4")
    XCTAssertEqual(plan.output.sidecarURLs.first?.lastPathComponent, "Custom Movie.2.eng.srt")
  }

  func testArchiveKeepsMKVContainerAndCopiesAllStreams() throws {
    let planner = ConversionPlanner(
      outputPathResolver: OutputPathResolver(fileChecker: EmptyFileChecker()))
    let plan = try planner.makePlan(
      for: media(videoCodec: "vp9", audioCodec: "flac", subtitleCodec: "subrip"),
      preset: .archive,
      outputOptions: OutputOptions()
    )

    XCTAssertEqual(plan.mode, .archive)
    XCTAssertTrue(plan.canExecute)
    XCTAssertEqual(plan.output.videoURL.pathExtension, "mkv")
    XCTAssertTrue(plan.primaryCommand.arguments.contains("-map"))
    XCTAssertTrue(plan.primaryCommand.arguments.contains("0"))
  }

  private func media(
    videoCodec: String = "h264",
    audioCodec: String,
    subtitleCodec: String?
  ) -> ProbedMediaFile {
    var streams = [
      stream(index: 0, kind: .video, codecName: videoCodec),
      stream(index: 1, kind: .audio, codecName: audioCodec),
    ]

    if let subtitleCodec {
      streams.append(
        stream(index: 2, kind: .subtitle, codecName: subtitleCodec, language: "eng")
      )
    }

    return ProbedMediaFile(
      sourceURL: URL(fileURLWithPath: "/Movies/Movie.mkv"),
      formatName: "matroska",
      duration: 90,
      streams: streams,
      chapters: [],
      metadata: [:]
    )
  }

  private func stream(
    index: Int,
    kind: MediaStreamKind,
    codecName: String,
    language: String? = nil
  ) -> MediaStream {
    MediaStream(
      index: index,
      kind: kind,
      codecName: codecName,
      codecLongName: nil,
      language: language,
      title: nil,
      width: nil,
      height: nil,
      channelCount: nil
    )
  }
}
