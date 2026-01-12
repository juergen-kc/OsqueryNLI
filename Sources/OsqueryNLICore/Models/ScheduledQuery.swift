import Foundation

/// Interval at which scheduled queries run
public enum ScheduleInterval: String, Codable, CaseIterable, Sendable {
    case every5Minutes = "5min"
    case every15Minutes = "15min"
    case every30Minutes = "30min"
    case hourly = "1hour"
    case every6Hours = "6hours"
    case daily = "daily"

    public var seconds: TimeInterval {
        switch self {
        case .every5Minutes: return 300
        case .every15Minutes: return 900
        case .every30Minutes: return 1800
        case .hourly: return 3600
        case .every6Hours: return 21600
        case .daily: return 86400
        }
    }

    public var displayName: String {
        switch self {
        case .every5Minutes: return "Every 5 minutes"
        case .every15Minutes: return "Every 15 minutes"
        case .every30Minutes: return "Every 30 minutes"
        case .hourly: return "Hourly"
        case .every6Hours: return "Every 6 hours"
        case .daily: return "Daily"
        }
    }
}

/// A query scheduled to run at regular intervals
public struct ScheduledQuery: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var query: String
    public var isSQL: Bool
    public var interval: ScheduleInterval
    public var isEnabled: Bool
    public var lastRun: Date?
    public var lastResultCount: Int?
    public var alertRule: AlertRule?
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        query: String,
        isSQL: Bool = false,
        interval: ScheduleInterval = .hourly,
        isEnabled: Bool = true,
        lastRun: Date? = nil,
        lastResultCount: Int? = nil,
        alertRule: AlertRule? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.query = query
        self.isSQL = isSQL
        self.interval = interval
        self.isEnabled = isEnabled
        self.lastRun = lastRun
        self.lastResultCount = lastResultCount
        self.alertRule = alertRule
        self.createdAt = createdAt
    }

    /// Check if the query should run based on its interval and last run time
    public func shouldRun(at date: Date = Date()) -> Bool {
        guard isEnabled else { return false }
        guard let lastRun = lastRun else { return true }
        return date.timeIntervalSince(lastRun) >= interval.seconds
    }
}
