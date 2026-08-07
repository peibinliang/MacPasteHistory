import XCTest

@testable import MacPasteHistory

final class SearchQueryParserTests: XCTestCase {
    private let fixedNow = Date(timeIntervalSince1970: 1_700_000_000)

    func testParse_extractsOrdinaryTermsAndSupportedStructuredValues() {
        let parser = makeParser()

        XCTAssertEqual(parser.parse("docker compose").terms, ["docker", "compose"])
        XCTAssertEqual(parser.parse("app:\"Visual Studio Code\" json").app, "Visual Studio Code")
        XCTAssertEqual(parser.parse("type:jwt").type, .jwt)
        XCTAssertEqual(parser.parse("type:text").type, .plainText)
        XCTAssertEqual(parser.parse("fav:false").favorite, false)
    }

    func testParse_handlesDatesUnknownPrefixesRepeatedValuesAndInvalidKnownValues() {
        let parser = makeParser()
        let expectedBefore = Calendar.utc.date(byAdding: .day, value: -7, to: fixedNow)
        let expectedAfter = Calendar.utc.date(byAdding: .day, value: -30, to: fixedNow)
        let absoluteDate = Calendar.utc.date(from: DateComponents(year: 2026, month: 8, day: 5))

        XCTAssertEqual(parser.parse("before:7d after:30d").before, expectedBefore)
        XCTAssertEqual(parser.parse("before:7d after:30d").after, expectedAfter)
        XCTAssertEqual(parser.parse("after:2026-08-05").after, absoluteDate)
        XCTAssertEqual(parser.parse("repo:foo").terms, ["repo:foo"])

        let invalidFavorite = parser.parse("fav:yes")
        XCTAssertEqual(invalidFavorite.tokens.map(\.kind), [.invalid(prefix: "fav", value: "yes")])
        XCTAssertEqual(invalidFavorite.issues.map(\.kind), [.invalidValue])

        let repeated = parser.parse(
            "app:Old app:Newest type:url type:jwt fav:false fav:true before:1d before:7d after:1d after:30d"
        )
        XCTAssertEqual(repeated.app, "Newest")
        XCTAssertEqual(repeated.type, .jwt)
        XCTAssertEqual(repeated.favorite, true)
        XCTAssertEqual(repeated.before, expectedBefore)
        XCTAssertEqual(repeated.after, expectedAfter)
        XCTAssertEqual(repeated.tokens.count, 5)
    }

    func testParse_preservesRawRangesEscapedQuotedValuesAndNonfatalUnterminatedQuotes() {
        let parser = makeParser()
        let input = "app:\"Visual \\\"Studio\\\\ Code\" type:json"

        let parsed = parser.parse(input)

        XCTAssertEqual(parsed.rawInput, input)
        XCTAssertEqual(parsed.app, "Visual \"Studio\\ Code")
        XCTAssertEqual(String(input[parsed.tokens[0].range]), "app:\"Visual \\\"Studio\\\\ Code\"")

        let unterminated = parser.parse("app:\"Visual Studio")
        XCTAssertEqual(unterminated.terms, ["app:Visual Studio"])
        XCTAssertEqual(unterminated.issues.map(\.kind), [.unterminatedQuote])
        XCTAssertTrue(unterminated.tokens.isEmpty)
    }

    private func makeParser() -> SearchQueryParser {
        SearchQueryParser(calendar: .utc, now: { self.fixedNow })
    }
}

private extension Calendar {
    static var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }
}
