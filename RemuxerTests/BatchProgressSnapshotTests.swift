import XCTest

@testable import Remuxer

final class BatchProgressSnapshotTests: XCTestCase {
  func testCombinesCompletedAndActiveItemProgress() {
    let items = [
      queueItem(status: .completed, progress: 1),
      queueItem(status: .converting, progress: 0.5),
      queueItem(status: .ready, progress: 0),
    ]

    let snapshot = BatchProgressSnapshot.make(
      items: items,
      targetIDs: [],
      isWorking: true,
      startedAt: nil,
      now: Date()
    )

    XCTAssertEqual(snapshot.totalCount, 3)
    XCTAssertEqual(snapshot.completedCount, 1)
    XCTAssertEqual(snapshot.progress, 0.5, accuracy: 0.001)
    XCTAssertNil(snapshot.estimatedTimeRemaining)
  }

  func testEstimatesRemainingTimeWhenDurationDataIsAvailable() {
    let startedAt = Date(timeIntervalSinceReferenceDate: 1_000)
    let now = startedAt.addingTimeInterval(60)
    let items = [
      queueItem(status: .completed, progress: 1, duration: 100),
      queueItem(status: .converting, progress: 0.5, duration: 100),
      queueItem(status: .ready, progress: 0, duration: 100),
    ]

    let snapshot = BatchProgressSnapshot.make(
      items: items,
      targetIDs: [],
      isWorking: true,
      startedAt: startedAt,
      now: now
    )

    XCTAssertEqual(snapshot.progress, 0.5, accuracy: 0.001)
    XCTAssertEqual(snapshot.estimatedTimeRemaining ?? -1, 60, accuracy: 0.001)
  }

  func testHidesEstimateWhenFutureDurationsAreUnknown() {
    let startedAt = Date(timeIntervalSinceReferenceDate: 1_000)
    let items = [
      queueItem(status: .completed, progress: 1, duration: 100),
      queueItem(status: .converting, progress: 0.5, duration: 100),
      queueItem(status: .ready, progress: 0, duration: nil),
    ]

    let snapshot = BatchProgressSnapshot.make(
      items: items,
      targetIDs: [],
      isWorking: true,
      startedAt: startedAt,
      now: startedAt.addingTimeInterval(60)
    )

    XCTAssertEqual(snapshot.progress, 0.5, accuracy: 0.001)
    XCTAssertNil(snapshot.estimatedTimeRemaining)
  }

  private func queueItem(
    status: QueueItemStatus,
    progress: Double,
    duration: TimeInterval? = 100
  ) -> QueueItem {
    QueueItem(
      sourceURL: URL(fileURLWithPath: "/Movies/\(UUID().uuidString).mkv"),
      status: status,
      media: duration.map(mediaFile(duration:)),
      progress: progress
    )
  }

  private func mediaFile(duration: TimeInterval) -> ProbedMediaFile {
    ProbedMediaFile(
      sourceURL: URL(fileURLWithPath: "/Movies/Movie.mkv"),
      formatName: "matroska",
      duration: duration,
      streams: [],
      chapters: [],
      metadata: [:]
    )
  }
}
