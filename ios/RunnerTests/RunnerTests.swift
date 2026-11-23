import Foundation
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {
  func testOwnerStorageDirectoriesAreExcludedFromBackup() throws {
    let fileManager = FileManager.default
    let support = fileManager.temporaryDirectory.appendingPathComponent(
      UUID().uuidString, isDirectory: true
    )
    defer { try? fileManager.removeItem(at: support) }

    for _ in 0..<2 {
      AppDelegate.excludeOwnerStorageFromBackup(in: support, fileManager: fileManager)
      for name in ["databases", "storage-coordination"] {
        let directory = support.appendingPathComponent(name, isDirectory: true)
        let values = try directory.resourceValues(forKeys: [.isExcludedFromBackupKey])
        XCTAssertEqual(values.isExcludedFromBackup, true, name)
      }
    }
  }
}
