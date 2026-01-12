import Testing
import Foundation
@testable import OsqueryNLICore

@Suite("AlertRule Tests")
struct AlertRuleTests {

    // MARK: - AlertCondition Evaluation Tests

    @Suite("AlertCondition Evaluation")
    struct AlertConditionEvaluationTests {

        @Test("anyResults returns true when results exist")
        func testAnyResultsTrue() {
            let condition = AlertCondition.anyResults
            let results: [[String: Any]] = [["name": "test"]]
            #expect(condition.evaluate(results: results) == true)
        }

        @Test("anyResults returns false when no results")
        func testAnyResultsFalse() {
            let condition = AlertCondition.anyResults
            let results: [[String: Any]] = []
            #expect(condition.evaluate(results: results) == false)
        }

        @Test("noResults returns true when empty")
        func testNoResultsTrue() {
            let condition = AlertCondition.noResults
            let results: [[String: Any]] = []
            #expect(condition.evaluate(results: results) == true)
        }

        @Test("noResults returns false when results exist")
        func testNoResultsFalse() {
            let condition = AlertCondition.noResults
            let results: [[String: Any]] = [["name": "test"]]
            #expect(condition.evaluate(results: results) == false)
        }

        @Test("rowCountGreaterThan evaluates correctly")
        func testRowCountGreaterThan() {
            let condition = AlertCondition.rowCountGreaterThan(5)

            #expect(condition.evaluate(results: Array(repeating: ["a": 1], count: 6)) == true)
            #expect(condition.evaluate(results: Array(repeating: ["a": 1], count: 5)) == false)
            #expect(condition.evaluate(results: Array(repeating: ["a": 1], count: 4)) == false)
        }

        @Test("rowCountLessThan evaluates correctly")
        func testRowCountLessThan() {
            let condition = AlertCondition.rowCountLessThan(5)

            #expect(condition.evaluate(results: Array(repeating: ["a": 1], count: 4)) == true)
            #expect(condition.evaluate(results: Array(repeating: ["a": 1], count: 5)) == false)
            #expect(condition.evaluate(results: Array(repeating: ["a": 1], count: 6)) == false)
        }

        @Test("rowCountEquals evaluates correctly")
        func testRowCountEquals() {
            let condition = AlertCondition.rowCountEquals(3)

            #expect(condition.evaluate(results: Array(repeating: ["a": 1], count: 3)) == true)
            #expect(condition.evaluate(results: Array(repeating: ["a": 1], count: 2)) == false)
            #expect(condition.evaluate(results: Array(repeating: ["a": 1], count: 4)) == false)
        }

        @Test("rowCountNotEquals evaluates correctly")
        func testRowCountNotEquals() {
            let condition = AlertCondition.rowCountNotEquals(3)

            #expect(condition.evaluate(results: Array(repeating: ["a": 1], count: 3)) == false)
            #expect(condition.evaluate(results: Array(repeating: ["a": 1], count: 2)) == true)
            #expect(condition.evaluate(results: Array(repeating: ["a": 1], count: 4)) == true)
        }

        @Test("containsValue finds matching value")
        func testContainsValueMatch() {
            let condition = AlertCondition.containsValue(column: "name", value: "chrome")
            let results: [[String: Any]] = [
                ["name": "Safari", "pid": 123],
                ["name": "Google Chrome", "pid": 456]
            ]
            #expect(condition.evaluate(results: results) == true)
        }

        @Test("containsValue is case insensitive")
        func testContainsValueCaseInsensitive() {
            let condition = AlertCondition.containsValue(column: "name", value: "CHROME")
            let results: [[String: Any]] = [["name": "google chrome"]]
            #expect(condition.evaluate(results: results) == true)
        }

        @Test("containsValue returns false when no match")
        func testContainsValueNoMatch() {
            let condition = AlertCondition.containsValue(column: "name", value: "firefox")
            let results: [[String: Any]] = [["name": "Chrome"], ["name": "Safari"]]
            #expect(condition.evaluate(results: results) == false)
        }

        @Test("containsValue returns false for missing column")
        func testContainsValueMissingColumn() {
            let condition = AlertCondition.containsValue(column: "missing", value: "test")
            let results: [[String: Any]] = [["name": "test"]]
            #expect(condition.evaluate(results: results) == false)
        }
    }

    // MARK: - AlertCondition Display Name Tests

    @Suite("AlertCondition Display Names")
    struct AlertConditionDisplayNameTests {

        @Test("displayName for anyResults")
        func testAnyResultsDisplayName() {
            #expect(AlertCondition.anyResults.displayName == "Any results found")
        }

        @Test("displayName for noResults")
        func testNoResultsDisplayName() {
            #expect(AlertCondition.noResults.displayName == "No results")
        }

        @Test("displayName for rowCountGreaterThan")
        func testRowCountGreaterThanDisplayName() {
            #expect(AlertCondition.rowCountGreaterThan(10).displayName == "More than 10 results")
        }

        @Test("displayName for containsValue")
        func testContainsValueDisplayName() {
            let condition = AlertCondition.containsValue(column: "status", value: "error")
            #expect(condition.displayName == "status contains 'error'")
        }
    }

    // MARK: - AlertConditionType Tests

    @Suite("AlertConditionType")
    struct AlertConditionTypeTests {

        @Test("needsThreshold is true for numeric conditions")
        func testNeedsThreshold() {
            #expect(AlertConditionType.moreThan.needsThreshold == true)
            #expect(AlertConditionType.lessThan.needsThreshold == true)
            #expect(AlertConditionType.equals.needsThreshold == true)
            #expect(AlertConditionType.notEquals.needsThreshold == true)
        }

        @Test("needsThreshold is false for simple conditions")
        func testNeedsThresholdFalse() {
            #expect(AlertConditionType.anyResults.needsThreshold == false)
            #expect(AlertConditionType.noResults.needsThreshold == false)
            #expect(AlertConditionType.contains.needsThreshold == false)
        }

        @Test("needsColumnValue is true only for contains")
        func testNeedsColumnValue() {
            #expect(AlertConditionType.contains.needsColumnValue == true)
            #expect(AlertConditionType.anyResults.needsColumnValue == false)
            #expect(AlertConditionType.moreThan.needsColumnValue == false)
        }
    }

    // MARK: - AlertRule Tests

    @Suite("AlertRule Behavior")
    struct AlertRuleBehaviorTests {

        @Test("shouldAlert returns true when condition matches and notifyOnMatch")
        func testShouldAlertOnMatch() {
            let rule = AlertRule(condition: .anyResults, notifyOnMatch: true)
            let results: [[String: Any]] = [["name": "test"]]
            #expect(rule.shouldAlert(results: results, previousResultCount: nil) == true)
        }

        @Test("shouldAlert returns false when condition doesn't match")
        func testShouldAlertNoMatch() {
            let rule = AlertRule(condition: .anyResults, notifyOnMatch: true)
            let results: [[String: Any]] = []
            #expect(rule.shouldAlert(results: results, previousResultCount: nil) == false)
        }

        @Test("shouldAlert returns true when count changes and notifyOnChange")
        func testShouldAlertOnChange() {
            let rule = AlertRule(condition: .noResults, notifyOnMatch: false, notifyOnChange: true)
            let results: [[String: Any]] = [["a": 1], ["a": 2]]
            #expect(rule.shouldAlert(results: results, previousResultCount: 5) == true)
        }

        @Test("shouldAlert returns false when count unchanged")
        func testShouldAlertNoChange() {
            let rule = AlertRule(condition: .noResults, notifyOnMatch: false, notifyOnChange: true)
            let results: [[String: Any]] = [["a": 1], ["a": 2]]
            #expect(rule.shouldAlert(results: results, previousResultCount: 2) == false)
        }

        @Test("shouldAlert with notifyOnMatch and notifyOnChange both false")
        func testShouldAlertBothFalse() {
            let rule = AlertRule(condition: .anyResults, notifyOnMatch: false, notifyOnChange: false)
            let results: [[String: Any]] = [["a": 1]]
            #expect(rule.shouldAlert(results: results, previousResultCount: 0) == false)
        }
    }

    // MARK: - AlertRule Codable Tests

    @Suite("AlertRule Codable")
    struct AlertRuleCodableTests {

        @Test("AlertRule encodes and decodes correctly")
        func testAlertRuleCodable() throws {
            let rule = AlertRule(
                condition: .rowCountGreaterThan(5),
                notifyOnMatch: true,
                notifyOnChange: false
            )

            let encoder = JSONEncoder()
            let data = try encoder.encode(rule)

            let decoder = JSONDecoder()
            let decoded = try decoder.decode(AlertRule.self, from: data)

            #expect(decoded.condition == rule.condition)
            #expect(decoded.notifyOnMatch == rule.notifyOnMatch)
            #expect(decoded.notifyOnChange == rule.notifyOnChange)
        }

        @Test("AlertCondition with containsValue encodes correctly")
        func testContainsValueCodable() throws {
            let condition = AlertCondition.containsValue(column: "status", value: "error")

            let encoder = JSONEncoder()
            let data = try encoder.encode(condition)

            let decoder = JSONDecoder()
            let decoded = try decoder.decode(AlertCondition.self, from: data)

            #expect(decoded == condition)
        }
    }
}
