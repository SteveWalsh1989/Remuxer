import XCTest

@testable import Remuxer

final class ConversionPlannerTests: XCTestCase {
  func testLosslessMP4SkipsSubtitleSidecarsByDefault() throws {
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
    XCTAssertTrue(plan.subtitleExtractionCommands.isEmpty)
    XCTAssertTrue(plan.output.sidecarURLs.isEmpty)
    XCTAssertEqual(plan.output.videoURL.lastPathComponent, "Movie.mp4")
    XCTAssertTrue(
      plan.warnings.contains {
        $0.message
          == "Subtitle stream #2 uses subrip and will not be included because extra subtitle file extraction is off."
      }
    )
  }

  func testLosslessMP4ExtractsSubtitleSidecarsWhenEnabled() throws {
    let planner = ConversionPlanner(
      outputPathResolver: OutputPathResolver(fileChecker: EmptyFileChecker()))
    var outputOptions = OutputOptions()
    outputOptions.extractSubtitleSidecars = true

    let plan = try planner.makePlan(
      for: media(audioCodec: "aac", subtitleCodec: "subrip"),
      preset: .losslessMP4,
      outputOptions: outputOptions
    )

    XCTAssertEqual(plan.subtitleExtractionCommands.count, 1)
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

  func testLosslessMP4WarnsAndSkipsAttachedPictureVideoStreams() throws {
    let planner = ConversionPlanner(
      outputPathResolver: OutputPathResolver(fileChecker: EmptyFileChecker()))
    let plan = try planner.makePlan(
      for: media(
        audioCodec: "aac",
        subtitleCodec: nil,
        extraStreams: [
          stream(
            index: 3, kind: .video, codecName: "mjpeg", title: "Cover", isAttachedPicture: true)
        ]),
      preset: .losslessMP4,
      outputOptions: OutputOptions()
    )

    XCTAssertTrue(plan.canExecute)
    XCTAssertFalse(plan.primaryCommand.arguments.contains("0:3"))
    XCTAssertTrue(
      plan.warnings.contains {
        $0.message
          == "Attachments and cover art cannot be preserved in MP4 and are not mapped into the output."
      }
    )
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
    XCTAssertTrue(plan.subtitleExtractionCommands.isEmpty)
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

    XCTAssertTrue(plan.primaryCommand.arguments.contains("h264_videotoolbox"))
    XCTAssertTrue(plan.primaryCommand.arguments.contains("75"))
  }

  func testCustomOutputNameAppliesToVideoAndSidecarsWhenExtractionIsEnabled() throws {
    let planner = ConversionPlanner(
      outputPathResolver: OutputPathResolver(fileChecker: EmptyFileChecker()))
    var outputOptions = OutputOptions()
    outputOptions.extractSubtitleSidecars = true

    let plan = try planner.makePlan(
      for: media(audioCodec: "aac", subtitleCodec: "subrip"),
      preset: .losslessMP4,
      outputOptions: outputOptions,
      customOutputName: "Custom Movie"
    )

    XCTAssertEqual(plan.output.videoURL.lastPathComponent, "Custom Movie.mp4")
    XCTAssertEqual(plan.output.sidecarURLs.first?.lastPathComponent, "Custom Movie.2.eng.srt")
  }

  func testArchiveKeepsMKVContainerAndCopiesAllStreams() throws {
    let planner = ConversionPlanner(
      outputPathResolver: OutputPathResolver(fileChecker: EmptyFileChecker()))
    var outputOptions = OutputOptions()
    outputOptions.removeSourceAfterSuccess = false

    let plan = try planner.makePlan(
      for: media(videoCodec: "vp9", audioCodec: "flac", subtitleCodec: "subrip"),
      preset: .archive,
      outputOptions: outputOptions
    )

    XCTAssertEqual(plan.mode, .archive)
    XCTAssertTrue(plan.canExecute)
    XCTAssertEqual(plan.output.videoURL.pathExtension, "mkv")
    XCTAssertTrue(plan.primaryCommand.arguments.contains("-map"))
    XCTAssertTrue(plan.primaryCommand.arguments.contains("0"))
  }

  func testSourceRemovalBlocksWhenOutputWouldReplaceSource() throws {
    let planner = ConversionPlanner(
      outputPathResolver: OutputPathResolver(fileChecker: EmptyFileChecker()))
    var outputOptions = OutputOptions()
    outputOptions.collisionResolution = .replace
    outputOptions.removeSourceAfterSuccess = true

    let plan = try planner.makePlan(
      for: media(videoCodec: "h264", audioCodec: "aac", subtitleCodec: nil),
      preset: .archive,
      outputOptions: outputOptions
    )

    XCTAssertFalse(plan.canExecute)
    XCTAssertTrue(
      plan.blockers.contains {
        $0.message
          == "The original file cannot be removed because the output path is the source file."
      }
    )
  }

  private func media(
    videoCodec: String = "h264",
    audioCodec: String,
    subtitleCodec: String?,
    extraStreams: [MediaStream] = []
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
    streams.append(contentsOf: extraStreams)

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
    language: String? = nil,
    title: String? = nil,
    isAttachedPicture: Bool = false
  ) -> MediaStream {
    MediaStream(
      index: index,
      kind: kind,
      codecName: codecName,
      codecLongName: nil,
      language: language,
      title: title,
      width: nil,
      height: nil,
      channelCount: nil,
      isAttachedPicture: isAttachedPicture
    )
  }
}
