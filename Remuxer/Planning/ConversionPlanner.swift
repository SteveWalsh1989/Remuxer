import Foundation

protocol ConversionPlanGenerating {
  func makePlan(
    for media: ProbedMediaFile,
    preset: ConversionPreset,
    outputOptions: OutputOptions,
    customOutputName: String?
  ) throws -> ConversionPlan
}

extension ConversionPlanGenerating {
  func makePlan(
    for media: ProbedMediaFile,
    preset: ConversionPreset,
    outputOptions: OutputOptions
  ) throws -> ConversionPlan {
    try makePlan(
      for: media,
      preset: preset,
      outputOptions: outputOptions,
      customOutputName: nil
    )
  }
}

struct ConversionPlanner: ConversionPlanGenerating {
  let outputPathResolver: OutputPathResolver

  init(outputPathResolver: OutputPathResolver = OutputPathResolver()) {
    self.outputPathResolver = outputPathResolver
  }

  func makePlan(
    for media: ProbedMediaFile,
    preset: ConversionPreset,
    outputOptions: OutputOptions,
    customOutputName: String? = nil
  ) throws -> ConversionPlan {
    let outputURL = try outputPathResolver.videoOutputURL(
      for: media.sourceURL,
      preset: preset,
      options: outputOptions,
      customOutputName: customOutputName
    )
    let subtitlePlan = try subtitleExtractionPlan(
      for: media,
      preset: preset,
      outputOptions: outputOptions,
      customOutputName: customOutputName
    )

    switch preset {
    case .losslessMP4:
      return try losslessMP4Plan(
        for: media,
        outputURL: outputURL,
        subtitlePlan: subtitlePlan,
        outputOptions: outputOptions
      )
    case .appleHEVC:
      return transcodePlan(
        for: media,
        preset: preset,
        outputURL: outputURL,
        subtitlePlan: subtitlePlan,
        outputOptions: outputOptions,
        videoArguments: ["-c:v", "hevc_videotoolbox", "-q:v", "65", "-tag:v", "hvc1"]
      )
    case .universalMP4:
      return transcodePlan(
        for: media,
        preset: preset,
        outputURL: outputURL,
        subtitlePlan: subtitlePlan,
        outputOptions: outputOptions,
        videoArguments: ["-c:v", "h264_videotoolbox", "-q:v", "75", "-pix_fmt", "yuv420p"]
      )
    case .archive:
      return archivePlan(
        for: media,
        outputURL: outputURL,
        subtitlePlan: subtitlePlan,
        outputOptions: outputOptions
      )
    }
  }

  private func losslessMP4Plan(
    for media: ProbedMediaFile,
    outputURL: URL,
    subtitlePlan: SubtitleExtractionPlan,
    outputOptions: OutputOptions
  ) throws -> ConversionPlan {
    var warnings = subtitlePlan.warnings
    var blockers = requiredVideoBlockers(for: media)
    blockers.append(
      contentsOf: sourceRemovalBlockers(
        for: media,
        outputURL: outputURL,
        outputOptions: outputOptions
      ))
    let compatibleVideoStreams = media.videoStreams.filter(
      StreamCompatibilityRules.canCopyVideoToMP4)
    let compatibleAudioStreams = media.audioStreams.filter(
      StreamCompatibilityRules.canCopyAudioToMP4)
    let compatibleSubtitleStreams = media.subtitleStreams.filter(
      StreamCompatibilityRules.canCopySubtitleToMP4)

    blockers.append(
      contentsOf: media.videoStreams
        .filter { StreamCompatibilityRules.canCopyVideoToMP4($0) == false }
        .map {
          PlanIssue(
            severity: .blocker,
            message:
              "Video stream #\($0.index) uses \($0.codecName), which cannot be copied into MP4."
          )
        }
    )
    blockers.append(
      contentsOf: media.audioStreams
        .filter { StreamCompatibilityRules.canCopyAudioToMP4($0) == false }
        .map {
          PlanIssue(
            severity: .blocker,
            message:
              "Audio stream #\($0.index) uses \($0.codecName), which would require audio transcoding."
          )
        }
    )

    warnings.append(contentsOf: mp4ContainerWarnings(for: media))

    let mappedStreams = compatibleVideoStreams + compatibleAudioStreams + compatibleSubtitleStreams
    let command = ProcessCommand(
      executableName: "ffmpeg",
      arguments: commonInputArguments(for: media, outputOptions: outputOptions)
        + mapArguments(for: mappedStreams)
        + ["-map_metadata", "0", "-map_chapters", "0", "-c", "copy", outputURL.path]
    )

    return ConversionPlan(
      preset: .losslessMP4,
      mode: .remux,
      primaryCommand: command,
      subtitleExtractionCommands: subtitlePlan.commands,
      warnings: warnings,
      blockers: blockers,
      output: PlannedOutput(videoURL: outputURL, sidecarURLs: subtitlePlan.outputURLs)
    )
  }

  private func transcodePlan(
    for media: ProbedMediaFile,
    preset: ConversionPreset,
    outputURL: URL,
    subtitlePlan: SubtitleExtractionPlan,
    outputOptions: OutputOptions,
    videoArguments: [String]
  ) -> ConversionPlan {
    var warnings = subtitlePlan.warnings
    var blockers = requiredVideoBlockers(for: media)
    blockers.append(
      contentsOf: sourceRemovalBlockers(
        for: media,
        outputURL: outputURL,
        outputOptions: outputOptions
      ))
    let incompatibleAudioStreams = media.audioStreams.filter { stream in
      StreamCompatibilityRules.canCopyAudioToMP4(stream) == false
    }
    let compatibleSubtitleStreams = media.subtitleStreams.filter(
      StreamCompatibilityRules.canCopySubtitleToMP4)
    let mappedStreams = media.videoStreams + media.audioStreams + compatibleSubtitleStreams

    warnings.append(
      contentsOf: incompatibleAudioStreams.map { stream in
        PlanIssue(
          severity: .warning,
          message:
            "Audio stream #\(stream.index) uses \(stream.codecName) and will be converted to AAC."
        )
      })
    warnings.append(contentsOf: mp4ContainerWarnings(for: media))

    var audioArguments: [String] = []
    if media.audioStreams.isEmpty == false {
      audioArguments = ["-c:a", "copy"]

      for stream in incompatibleAudioStreams {
        guard let outputAudioIndex = media.audioStreams.firstIndex(of: stream) else {
          continue
        }

        audioArguments += ["-c:a:\(outputAudioIndex)", "aac", "-b:a:\(outputAudioIndex)", "192k"]
      }
    }

    let command = ProcessCommand(
      executableName: "ffmpeg",
      arguments: commonInputArguments(for: media, outputOptions: outputOptions)
        + mapArguments(for: mappedStreams)
        + ["-map_metadata", "0", "-map_chapters", "0"]
        + videoArguments
        + audioArguments
        + ["-c:s", "copy", outputURL.path]
    )

    return ConversionPlan(
      preset: preset,
      mode: .transcode,
      primaryCommand: command,
      subtitleExtractionCommands: subtitlePlan.commands,
      warnings: warnings,
      blockers: blockers,
      output: PlannedOutput(videoURL: outputURL, sidecarURLs: subtitlePlan.outputURLs)
    )
  }

  private func archivePlan(
    for media: ProbedMediaFile,
    outputURL: URL,
    subtitlePlan: SubtitleExtractionPlan,
    outputOptions: OutputOptions
  ) -> ConversionPlan {
    let command = ProcessCommand(
      executableName: "ffmpeg",
      arguments: commonInputArguments(for: media, outputOptions: outputOptions)
        + ["-map", "0", "-map_metadata", "0", "-map_chapters", "0", "-c", "copy", outputURL.path]
    )

    return ConversionPlan(
      preset: .archive,
      mode: .archive,
      primaryCommand: command,
      subtitleExtractionCommands: [],
      warnings: [],
      blockers: requiredVideoBlockers(for: media)
        + sourceRemovalBlockers(for: media, outputURL: outputURL, outputOptions: outputOptions),
      output: PlannedOutput(videoURL: outputURL, sidecarURLs: subtitlePlan.outputURLs)
    )
  }

  private func subtitleExtractionPlan(
    for media: ProbedMediaFile,
    preset: ConversionPreset,
    outputOptions: OutputOptions,
    customOutputName: String?
  ) throws -> SubtitleExtractionPlan {
    guard preset != .archive else {
      return SubtitleExtractionPlan(commands: [], outputURLs: [], warnings: [])
    }

    let unsupportedSubtitleStreams = media.subtitleStreams.filter {
      StreamCompatibilityRules.canCopySubtitleToMP4($0) == false
    }

    guard outputOptions.extractSubtitleSidecars else {
      return SubtitleExtractionPlan(
        commands: [],
        outputURLs: [],
        warnings: unsupportedSubtitleStreams.map { stream in
          PlanIssue(
            severity: .warning,
            message:
              "Subtitle stream #\(stream.index) uses \(stream.codecName) and will not be included "
              + "because extra subtitle file extraction is off."
          )
        }
      )
    }

    var reservedURLs = Set<URL>()
    var outputURLs: [URL] = []
    var commands: [ProcessCommand] = []
    var warnings: [PlanIssue] = []

    for stream in unsupportedSubtitleStreams {
      let sidecarExtension = StreamCompatibilityRules.sidecarExtension(for: stream)
      let sidecarURL = try outputPathResolver.sidecarURL(
        for: media.sourceURL,
        stream: stream,
        extension: sidecarExtension,
        options: outputOptions,
        reservedURLs: reservedURLs,
        customOutputName: customOutputName,
        videoOutputExtension: preset.outputExtension
      )
      reservedURLs.insert(sidecarURL.standardizedFileURL)
      outputURLs.append(sidecarURL)
      commands.append(
        ProcessCommand(
          executableName: "ffmpeg",
          arguments: [
            "-hide_banner",
            "-y",
            "-i",
            media.sourceURL.path,
            "-map",
            "0:\(stream.index)",
            sidecarURL.path,
          ]
        )
      )
      warnings.append(
        PlanIssue(
          severity: .warning,
          message:
            "Subtitle stream #\(stream.index) uses \(stream.codecName) and will be extracted as "
            + "\(sidecarURL.lastPathComponent)."
        )
      )
    }

    return SubtitleExtractionPlan(commands: commands, outputURLs: outputURLs, warnings: warnings)
  }

  private func requiredVideoBlockers(for media: ProbedMediaFile) -> [PlanIssue] {
    if media.videoStreams.isEmpty {
      return [
        PlanIssue(
          severity: .blocker,
          message: "No video stream was found."
        )
      ]
    }

    return []
  }

  private func sourceRemovalBlockers(
    for media: ProbedMediaFile,
    outputURL: URL,
    outputOptions: OutputOptions
  ) -> [PlanIssue] {
    guard outputOptions.removeSourceAfterSuccess else {
      return []
    }

    guard outputURL.standardizedFileURL == media.sourceURL.standardizedFileURL else {
      return []
    }

    return [
      PlanIssue(
        severity: .blocker,
        message: "The original file cannot be removed because the output path is the source file."
      )
    ]
  }

  private func mp4ContainerWarnings(for media: ProbedMediaFile) -> [PlanIssue] {
    guard media.attachmentStreams.isEmpty == false else {
      return []
    }

    return [
      PlanIssue(
        severity: .warning,
        message:
          "Attachments and cover art cannot be preserved in MP4 and are not mapped into the output."
      )
    ]
  }

}

extension ConversionPlanner {
  fileprivate func commonInputArguments(for media: ProbedMediaFile, outputOptions: OutputOptions)
    -> [String]
  {
    [
      "-hide_banner",
      outputOptions.collisionResolution == .replace ? "-y" : "-n",
      "-i",
      media.sourceURL.path,
    ]
  }

  fileprivate func mapArguments(for streams: [MediaStream]) -> [String] {
    streams.flatMap { ["-map", "0:\($0.index)"] }
  }
}

private struct SubtitleExtractionPlan {
  let commands: [ProcessCommand]
  let outputURLs: [URL]
  let warnings: [PlanIssue]
}
