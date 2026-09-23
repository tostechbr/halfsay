import Foundation
import Testing
@testable import PartwayCore

@Suite struct KeystrokesTests {
    @Test func shortTextIsOneChunk() {
        #expect(Keystrokes.chunks("hello") == ["hello"])
    }

    @Test func longTextSplitsAtTwentyUnits() {
        #expect(Keystrokes.chunks(String(repeating: "a", count: 25)) == [String(repeating: "a", count: 20), "aaaaa"])
    }

    @Test func neverSplitsACharacter() {
        let family = "👨‍👩‍👧‍👦"  // one Character, 11 UTF-16 units
        #expect(Keystrokes.chunks(family + family) == [family, family])
    }

    @Test func emptyTextTypesNothing() {
        #expect(Keystrokes.chunks("").isEmpty)
    }
}
