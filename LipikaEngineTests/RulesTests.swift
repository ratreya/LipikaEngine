/*
 * LipikaEngine is a multi-codepoint, user-configurable, phonetic, Transliteration Engine.
 * Copyright (C) 2017 Ranganath Atreya
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 */

import XCTest
@testable import LipikaEngine

class RulesTests: XCTestCase {
    var engine: Engine?
    
    override func setUp() {
        super.setUp()
        let testSchemesDirectory = Bundle(for: EngineFactoryTests.self).bundleURL.appendingPathComponent("Schemes")
        XCTAssertNotNil(testSchemesDirectory)
        XCTAssert(FileManager.default.fileExists(atPath: testSchemesDirectory.path))
        do {
            let factory = try EngineFactory(schemesDirectory: testSchemesDirectory)
            engine = try factory.engine(schemeName: "Barahavat", scriptName: "Hindi")
        }
        catch let error {
            XCTFail(error.localizedDescription)
        }
        XCTAssertNotNil(engine)
    }
    
    func testHappyCase() {
        XCTAssertNotNil(engine?.rules.state)
        XCTAssertEqual(engine?.rules.state.next["{CONSONANT}"]?.output?.generate(intermediates: ["A"]), "A")
        XCTAssertEqual(engine?.rules.state.next["{CONSONANT}"]?.next["{CONSONANT}"]?.output?.generate(intermediates: ["A", "A"]), "A्A")
    }
    
    func testDeepNesting() throws {
        XCTAssertNotNil(engine?.rules.state)
        XCTAssertEqual(engine?.rules.state.next["{CONSONANT}"]?.next["{CONSONANT}"]?.next["{SIGN/NUKTA}"]?.next["{DEPENDENT}"]?.output?.generate(intermediates: ["A", "B", "C", "D"]), "A्BCD")
    }
}
