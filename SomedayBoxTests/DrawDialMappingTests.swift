import Foundation
import XCTest
#if canImport(SomedayBox)
@testable import SomedayBox
#else
@testable import SomedayBoxDomain
#endif

/// `draw-dial-v1` fixtures: specification §7.3, acceptance DIAL-01, DIAL-02, DIAL-05.
final class DrawDialMappingTests: XCTestCase {
    func testEveryDetentMapsToItsExactPersistedRawValue() {
        XCTAssertEqual(DrawDialMapping.Detent.aFewMinutes.availableTime, .upTo10Minutes)
        XCTAssertEqual(DrawDialMapping.Detent.aboutAnHour.availableTime, .upTo60Minutes)
        XCTAssertEqual(DrawDialMapping.Detent.aFewHours.availableTime, .upTo240Minutes)
        XCTAssertEqual(DrawDialMapping.Detent.mostOfTheDay.availableTime, .upTo480Minutes)
        XCTAssertEqual(DrawDialMapping.Detent.allCases.count, 4)
    }

    func testDialIntroducesNoNewPersistedContextValue() {
        let existing = Set(AvailableTime.allCases.map(\.rawValue))
        var produced = Set(DrawDialMapping.Detent.allCases.map { $0.availableTime.rawValue })
        produced.insert(DrawDialMapping.availableTime(for: .notSure).rawValue)
        for minutes in stride(from: 10, through: 480, by: 5) {
            produced.insert(DrawDialMapping.availableTime(for: .custom(minutes: minutes)).rawValue)
        }
        XCTAssertTrue(produced.isSubset(of: existing))
    }

    func testSnapUsesTheLargestBucketAtOrBelowTheEnteredMinutes() {
        XCTAssertEqual(DrawDialMapping.snap(minutes: 10), .upTo10Minutes)
        XCTAssertEqual(DrawDialMapping.snap(minutes: 29), .upTo10Minutes)
        XCTAssertEqual(DrawDialMapping.snap(minutes: 30), .upTo30Minutes)
        XCTAssertEqual(DrawDialMapping.snap(minutes: 45), .upTo30Minutes)
        XCTAssertEqual(DrawDialMapping.snap(minutes: 90), .upTo60Minutes)
        XCTAssertEqual(DrawDialMapping.snap(minutes: 119), .upTo60Minutes)
        XCTAssertEqual(DrawDialMapping.snap(minutes: 120), .upTo120Minutes)
        XCTAssertEqual(DrawDialMapping.snap(minutes: 300), .upTo240Minutes)
        XCTAssertEqual(DrawDialMapping.snap(minutes: 480), .upTo480Minutes)
    }

    func testSnappedBucketIsAlwaysTrueForTheEnteredMinutes() {
        for minutes in DrawDialMapping.customMinutesRange {
            let snapped = DrawDialMapping.snap(minutes: minutes)
            XCTAssertLessThanOrEqual(
                snapped.maximumMinutes,
                minutes,
                "A snapped bucket wider than the entered time would overpromise at \(minutes) minutes."
            )
        }
    }

    func testCustomMinutesClampToTheWheelAndFloorOntoItsStep() {
        XCTAssertEqual(DrawDialMapping.normalizedCustomMinutes(0), 10)
        XCTAssertEqual(DrawDialMapping.normalizedCustomMinutes(9), 10)
        XCTAssertEqual(DrawDialMapping.normalizedCustomMinutes(10), 10)
        XCTAssertEqual(DrawDialMapping.normalizedCustomMinutes(34), 30)
        XCTAssertEqual(DrawDialMapping.normalizedCustomMinutes(480), 480)
        XCTAssertEqual(DrawDialMapping.normalizedCustomMinutes(999), 480)
    }

    func testFlooringOntoTheStepNeverChangesTheSnappedBucket() {
        for minutes in DrawDialMapping.customMinutesRange {
            let direct = DurationBucket.allCases
                .filter { $0.maximumMinutes <= minutes }
                .max { $0.maximumMinutes < $1.maximumMinutes }
            XCTAssertEqual(DrawDialMapping.snap(minutes: minutes), direct)
        }
    }

    func testDetentlessBucketsStayReachableThroughCustom() {
        XCTAssertEqual(DrawDialMapping.availableTime(for: .custom(minutes: 30)), .upTo30Minutes)
        XCTAssertEqual(DrawDialMapping.availableTime(for: .custom(minutes: 120)), .upTo120Minutes)
    }

    func testNotSureStaysItsOwnPersistedValue() {
        XCTAssertEqual(DrawDialMapping.availableTime(for: .notSure), .notSure)
    }
}
