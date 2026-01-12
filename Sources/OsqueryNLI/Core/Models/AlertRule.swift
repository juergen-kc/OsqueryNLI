import Foundation

/// Condition that triggers an alert
enum AlertCondition: Codable, Equatable, Sendable {
    case rowCountGreaterThan(Int)
    case rowCountLessThan(Int)
    case rowCountEquals(Int)
    case rowCountNotEquals(Int)
    case anyResults
    case noResults
    case containsValue(column: String, value: String)

    var displayName: String {
        switch self {
        case .rowCountGreaterThan(let n): return "More than \(n) results"
        case .rowCountLessThan(let n): return "Fewer than \(n) results"
        case .rowCountEquals(let n): return "Exactly \(n) results"
        case .rowCountNotEquals(let n): return "Not \(n) results"
        case .anyResults: return "Any results found"
        case .noResults: return "No results"
        case .containsValue(let col, let val): return "\(col) contains '\(val)'"
        }
    }

    /// Evaluate the condition against query results
    func evaluate(results: [[String: Any]]) -> Bool {
        let count = results.count

        switch self {
        case .rowCountGreaterThan(let n):
            return count > n
        case .rowCountLessThan(let n):
            return count < n
        case .rowCountEquals(let n):
            return count == n
        case .rowCountNotEquals(let n):
            return count != n
        case .anyResults:
            return count > 0
        case .noResults:
            return count == 0
        case .containsValue(let column, let value):
            return results.contains { row in
                if let cellValue = row[column] {
                    return String(describing: cellValue).localizedCaseInsensitiveContains(value)
                }
                return false
            }
        }
    }
}

/// Alert condition type for UI picker
enum AlertConditionType: String, CaseIterable, Sendable {
    case anyResults = "any"
    case noResults = "none"
    case moreThan = "more"
    case lessThan = "less"
    case equals = "equals"
    case notEquals = "notEquals"
    case contains = "contains"

    var displayName: String {
        switch self {
        case .anyResults: return "Any results"
        case .noResults: return "No results"
        case .moreThan: return "More than N"
        case .lessThan: return "Fewer than N"
        case .equals: return "Exactly N"
        case .notEquals: return "Not N"
        case .contains: return "Column contains"
        }
    }

    var needsThreshold: Bool {
        switch self {
        case .moreThan, .lessThan, .equals, .notEquals:
            return true
        default:
            return false
        }
    }

    var needsColumnValue: Bool {
        self == .contains
    }
}

/// Rule that defines when to send notifications for a scheduled query
struct AlertRule: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var condition: AlertCondition
    var notifyOnMatch: Bool
    var notifyOnChange: Bool
    var lastTriggered: Date?
    var lastResultHash: String?

    init(
        id: UUID = UUID(),
        condition: AlertCondition,
        notifyOnMatch: Bool = true,
        notifyOnChange: Bool = false,
        lastTriggered: Date? = nil,
        lastResultHash: String? = nil
    ) {
        self.id = id
        self.condition = condition
        self.notifyOnMatch = notifyOnMatch
        self.notifyOnChange = notifyOnChange
        self.lastTriggered = lastTriggered
        self.lastResultHash = lastResultHash
    }

    /// Check if alert should fire based on results and previous state
    func shouldAlert(results: [[String: Any]], previousResultCount: Int?) -> Bool {
        let conditionMet = condition.evaluate(results: results)

        if notifyOnMatch && conditionMet {
            return true
        }

        if notifyOnChange {
            if let previous = previousResultCount, previous != results.count {
                return true
            }
        }

        return false
    }
}
