import Foundation

protocol MediaAnalyzing {
  func analyze(url: URL) async throws -> ProbedMediaFile
}

struct FFprobeClient: MediaAnalyzing {
  let toolLocator: ToolLocating

  func analyze(url: URL) async throws -> ProbedMediaFile {
    let toolchain = try toolLocator.locateToolchain()
    let data = try await runFFprobe(url: url, ffprobeURL: toolchain.ffprobeURL)
    let output = try JSONDecoder().decode(FFprobeOutput.self, from: data)
    return output.mediaFile(sourceURL: url)
  }

  private func runFFprobe(url: URL, ffprobeURL: URL) async throws -> Data {
    let process = Process()
    let standardOutput = Pipe()
    let standardError = Pipe()

    process.executableURL = ffprobeURL
    process.arguments = [
      "-v",
      "error",
      "-print_format",
      "json",
      "-show_format",
      "-show_streams",
      "-show_chapters",
      url.path,
    ]
    process.standardOutput = standardOutput
    process.standardError = standardError

    try process.run()
    process.waitUntilExit()

    let data = standardOutput.fileHandleForReading.readDataToEndOfFile()
    if process.terminationStatus == 0 {
      return data
    }

    let errorData = standardError.fileHandleForReading.readDataToEndOfFile()
    let message = String(data: errorData, encoding: .utf8) ?? "ffprobe failed."
    throw ProcessExecutionError.failed(message.trimmingCharacters(in: .whitespacesAndNewlines))
  }
}
