import Testing
import Foundation
@testable import OsqueryNLICore

@Suite("ScheduledQuery Tests")
struct ScheduledQueryTests {

    // MARK: - ScheduleInterval Tests

    @Suite("ScheduleInterval")
    struct ScheduleIntervalTests {

        @Test("seconds returns correct values")
        func testSecondsValues() {
            #expect(ScheduleInterval.every5Minutes.seconds == 300)
            #expect(ScheduleInterval.every15Minutes.seconds == 900)
            #expect(ScheduleInterval.every30Minutes.seconds == 1800)
            #expect(ScheduleInterval.hourly.seconds == 3600)
            #expect(ScheduleInterval.every6Hours.seconds == 21600)
            #expect(ScheduleInterval.daily.seconds == 86400)
        }

        @Test("displayName returns human readable strings")
        func testDisplayNames() {
            #expect(ScheduleInterval.every5Minutes.displayName == "Every 5 minutes")
            #expect(ScheduleInterval.hourly.displayName == "Hourly")
            #expect(ScheduleInterval.daily.displayName == "Daily")
        }

        @Test("all intervals are in allCases")
        func testAllCases() {
            #expect(ScheduleInterval.allCases.count == 6)
            #expect(ScheduleInterval.allCases.contains(.every5Minutes))
            #expect(ScheduleInterval.allCases.contains(.daily))
        }
    }

    // MARK: - ScheduledQuery shouldRun Tests

    @Suite("ScheduledQuery shouldRun")
    struct ShouldRunTests {

        @Test("shouldRun returns true when never run")
        func testShouldRunNeverRun() {
            let query = ScheduledQuery(
                name: "Test",
                query: "SELECT 1",
                interval: .hourly,
                isEnabled: true,
                lastRun: nil
            )
            #expect(query.shouldRun() == true)
        }

        @Test("shouldRun returns false when disabled")
        func testShouldRunDisabled() {
            let query = ScheduledQuery(
                name: "Test",
                query: "SELECT 1",
                interval: .hourly,
                isEnabled: false,
                lastRun: nil
            )
            #expect(query.shouldRun() == false)
        }

        @Test("shouldRun returns true when interval elapsed")
        func testShouldRunIntervalElapsed() {
            let twoHoursAgo = Date().addingTimeInterval(-7200) // 2 hours ago
            let query = ScheduledQuery(
                name: "Test",
                query: "SELECT 1",
                interval: .hourly,
                isEnabled: true,
                lastRun: twoHoursAgo
            )
            #expect(query.shouldRun() == true)
        }

        @Test("shouldRun returns false when interval not elapsed")
        func testShouldRunIntervalNotElapsed() {
            let fiveMinutesAgo = Date().addingTimeInterval(-300)
            let query = ScheduledQuery(
                name: "Test",
                query: "SELECT 1",
                interval: .hourly,
                isEnabled: true,
                lastRun: fiveMinutesAgo
            )
            #expect(query.shouldRun() == false)
        }

        @Test("shouldRun respects exact boundary")
        func testShouldRunExactBoundary() {
            let exactlyOneHourAgo = Date().addingTimeInterval(-3600)
            let query = ScheduledQuery(
                name: "Test",
                query: "SELECT 1",
                interval: .hourly,
                isEnabled: true,
                lastRun: exactlyOneHourAgo
            )
            #expect(query.shouldRun() == true)
        }

        @Test("shouldRun with custom date")
        func testShouldRunCustomDate() {
            let baseDate = Date()
            let lastRun = baseDate.addingTimeInterval(-1800) // 30 min ago
            let checkTime = baseDate.addingTimeInterval(1800) // 30 min in future = 1 hour since lastRun

            let query = ScheduledQuery(
                name: "Test",
                query: "SELECT 1",
                interval: .hourly,
                isEnabled: true,
                lastRun: lastRun
            )
            #expect(query.shouldRun(at: checkTime) == true)
        }
    }

    // MARK: - ScheduledQuery Initialization Tests

    @Suite("ScheduledQuery Initialization")
    struct InitializationTests {

        @Test("default values are set correctly")
        func testDefaultValues() {
            let query = ScheduledQuery(name: "Test", query: "SELECT 1")

            #expect(query.name == "Test")
            #expect(query.query == "SELECT 1")
            #expect(query.isSQL == false)
            #expect(query.interval == .hourly)
            #expect(query.isEnabled == true)
            #expect(query.lastRun == nil)
            #expect(query.lastResultCount == nil)
            #expect(query.alertRule == nil)
        }

        @Test("custom values are preserved")
        func testCustomValues() {
            let alertRule = AlertRule(condition: .anyResults)
            let query = ScheduledQuery(
                name: "Custom",
                query: "SELECT * FROM processes",
                isSQL: true,
                interval: .daily,
                isEnabled: false,
                lastResultCount: 42,
                alertRule: alertRule
            )

            #expect(query.name == "Custom")
            #expect(query.isSQL == true)
            #expect(query.interval == .daily)
            #expect(query.isEnabled == false)
            #expect(query.lastResultCount == 42)
            #expect(query.alertRule != nil)
        }

        @Test("id is unique for each instance")
        func testUniqueId() {
            let query1 = ScheduledQuery(name: "A", query: "SELECT 1")
            let query2 = ScheduledQuery(name: "A", query: "SELECT 1")
            #expect(query1.id != query2.id)
        }
    }

    // MARK: - ScheduledQuery Codable Tests

    @Suite("ScheduledQuery Codable")
    struct CodableTests {

        @Test("encodes and decodes without alert rule")
        func testCodableWithoutAlert() throws {
            let query = ScheduledQuery(
                name: "Test",
                query: "SELECT 1",
                interval: .every15Minutes
            )

            let data = try JSONEncoder().encode(query)
            let decoded = try JSONDecoder().decode(ScheduledQuery.self, from: data)

            #expect(decoded.name == query.name)
            #expect(decoded.query == query.query)
            #expect(decoded.interval == query.interval)
            #expect(decoded.id == query.id)
        }

        @Test("encodes and decodes with alert rule")
        func testCodableWithAlert() throws {
            let alertRule = AlertRule(condition: .rowCountGreaterThan(10))
            let query = ScheduledQuery(
                name: "Alert Test",
                query: "SELECT * FROM processes",
                alertRule: alertRule
            )

            let data = try JSONEncoder().encode(query)
            let decoded = try JSONDecoder().decode(ScheduledQuery.self, from: data)

            #expect(decoded.alertRule != nil)
            #expect(decoded.alertRule?.condition == alertRule.condition)
        }
    }

    // MARK: - ScheduledQuery Hashable Tests

    @Suite("ScheduledQuery Hashable")
    struct HashableTests {

        @Test("equal queries have same hash value")
        func testEqualQueriesHaveSameHash() {
            let id = UUID()
            let date = Date()
            let query1 = ScheduledQuery(id: id, name: "A", query: "SELECT 1", createdAt: date)
            let query2 = ScheduledQuery(id: id, name: "A", query: "SELECT 1", createdAt: date)

            // Equal objects must have equal hash values
            #expect(query1.hashValue == query2.hashValue)
        }

        @Test("can be used in Set")
        func testSetUsage() {
            let query1 = ScheduledQuery(name: "A", query: "SELECT 1")
            let query2 = ScheduledQuery(name: "B", query: "SELECT 2")

            var set = Set<ScheduledQuery>()
            set.insert(query1)
            set.insert(query2)
            set.insert(query1) // Duplicate

            #expect(set.count == 2)
        }

        @Test("can be used as Dictionary key")
        func testDictionaryKey() {
            let query = ScheduledQuery(name: "Test", query: "SELECT 1")
            var dict: [ScheduledQuery: String] = [:]
            dict[query] = "value"

            #expect(dict[query] == "value")
        }
    }
}
