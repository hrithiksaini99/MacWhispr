import XCTest
@testable import MacWhispr

final class MacWhisprTests: XCTestCase {
    func testModelCatalogHasUniqueIDsAndFilenames() {
        XCTAssertEqual(Set(WhisperModel.all.map(\.id)).count, WhisperModel.all.count)
        XCTAssertEqual(Set(WhisperModel.all.map(\.filename)).count, WhisperModel.all.count)
        XCTAssertTrue(WhisperModel.all.allSatisfy { $0.filename.hasPrefix("ggml-") && $0.filename.hasSuffix(".bin") })
    }
    func testModePersistence() {
        let previous = ActivationMode.current
        defer { ActivationMode.current = previous }
        ActivationMode.current = .pushToTalk
        XCTAssertEqual(ActivationMode.current, .pushToTalk)
        ActivationMode.current = .toggle
        XCTAssertEqual(ActivationMode.current, .toggle)
    }
}
