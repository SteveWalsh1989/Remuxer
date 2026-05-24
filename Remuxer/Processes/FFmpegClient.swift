import Foundation

@MainActor
protocol ConversionExecuting: AnyObject {
  func run(
    _ command: ProcessCommand,
    duration: TimeInterval?,
    progress: @escaping @Sendable (Double) -> Void,
    log: @escaping @Sendable (String) -> Void
  ) async throws
  func cancel()
}

enum ProcessExecutionError: LocalizedError, Equatable {
  case failed(String)
  case cancelled

  var errorDescription: String? {
    switch self {
    case .failed(let message):
      message.isEmpty ? "The external process failed." : message
    case .cancelled:
      "Conversion was cancelled."
    }
  }
}

@MainActor
final class FFmpegClient: ConversionExecuting {
  private let toolLocator: ToolLocating
  private let processRunner: ExternalProcessRunning

  convenience init(toolLocator: ToolLocating) {
    self.init(toolLocator: toolLocator, processRunner: ProcessCommandRunner())
  }

  init(toolLocator: ToolLocating, processRunner: ExternalProcessRunning) {
    self.toolLocator = toolLocator
    self.processRunner = processRunner
  }

  func run(
    _ command: ProcessCommand,
    duration: TimeInterval?,
    progress: @escaping @Sendable (Double) -> Void,
    log: @escaping @Sendable (String) -> Void
  ) async throws {
    let toolchain = try toolLocator.locateToolchain()
    let executableURL = executableURL(for: command.executableName, in: toolchain)

    try await processRunner.run(
      executableURL: executableURL,
      arguments: command.arguments,
      duration: duration,
      progress: progress,
      log: log
    )
  }

  func cancel() {
    processRunner.cancel()
  }

  private func executableURL(for executableName: String, in toolchain: FFmpegToolchain) -> URL {
    switch executableName {
    case "ffprobe":
      toolchain.ffprobeURL
    default:
      toolchain.ffmpegURL
    }
  }
}

@MainActor
protocol ExternalProcessRunning: AnyObject {
  func run(
    executableURL: URL,
    arguments: [String],
    duration: TimeInterval?,
    progress: @escaping @Sendable (Double) -> Void,
    log: @escaping @Sendable (String) -> Void
  ) async throws
  func cancel()
}

@MainActor
final class ProcessCommandRunner: ExternalProcessRunning {
  private var activeProcess: Process?

  func run(
    executableURL: URL,
    arguments: [String],
    duration: TimeInterval?,
    progress: @escaping @Sendable (Double) -> Void,
    log: @escaping @Sendable (String) -> Void
  ) async throws {
    try await withCheckedThrowingContinuation { continuation in
      let process = Process()
      let standardError = Pipe()
      let outputBuffer = ProcessOutputBuffer()

      process.executableURL = executableURL
      process.arguments = arguments
      process.standardError = standardError
      activeProcess = process

      standardError.fileHandleForReading.readabilityHandler = { handle in
        let data = handle.availableData
        guard data.isEmpty == false, let text = String(data: data, encoding: .utf8) else {
          return
        }

        Task {
          await outputBuffer.append(text)
        }
        text.split(separator: "\n", omittingEmptySubsequences: true)
          .map(String.init)
          .forEach(log)

        if let duration,
          let parsedProgress = FFmpegProgressParser.progress(
            from: text,
            duration: duration
          )
        {
          progress(parsedProgress)
        }
      }

      process.terminationHandler = { [weak self] finishedProcess in
        standardError.fileHandleForReading.readabilityHandler = nil

        Task { @MainActor in
          self?.activeProcess = nil

          if finishedProcess.terminationStatus == 0 {
            progress(1)
            continuation.resume()
            return
          }

          if finishedProcess.terminationReason == .uncaughtSignal {
            continuation.resume(throwing: ProcessExecutionError.cancelled)
            return
          }

          let stderrText = await outputBuffer.text
          continuation.resume(
            throwing: ProcessExecutionError.failed(
              stderrText.trimmingCharacters(in: .whitespacesAndNewlines)
            )
          )
        }
      }

      do {
        try process.run()
      } catch {
        activeProcess = nil
        standardError.fileHandleForReading.readabilityHandler = nil
        continuation.resume(throwing: error)
      }
    }
  }

  func cancel() {
    activeProcess?.terminate()
  }
}

private actor ProcessOutputBuffer {
  private var accumulatedText = ""

  var text: String {
    accumulatedText
  }

  func append(_ text: String) {
    accumulatedText += text
  }
}

enum FFmpegProgressParser {
  static func progress(from text: String, duration: TimeInterval) -> Double? {
    guard duration > 0,
      let timeRange = text.range(of: #"time=\d{2}:\d{2}:\d{2}\.\d+"#, options: .regularExpression)
    else {
      return nil
    }

    let timestamp = String(text[timeRange]).replacingOccurrences(of: "time=", with: "")
    let parts = timestamp.split(separator: ":").compactMap(Double.init)

    guard parts.count == 3 else {
      return nil
    }

    let seconds = parts[0] * 3_600 + parts[1] * 60 + parts[2]
    return min(max(seconds / duration, 0), 1)
  }
}
