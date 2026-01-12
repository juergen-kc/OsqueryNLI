import Foundation

/// Supported export file types
public enum ExportFileType: String, Codable, CaseIterable, Sendable {
    case json
    case csv
    case markdown
    case xlsx

    public var displayName: String {
        switch self {
        case .json: return "JSON"
        case .csv: return "CSV"
        case .markdown: return "Markdown"
        case .xlsx: return "Excel"
        }
    }

    public var icon: String {
        switch self {
        case .json: return "curlybraces"
        case .csv: return "tablecells"
        case .markdown: return "text.document"
        case .xlsx: return "tablecells.badge.ellipsis"
        }
    }

    public var fileExtension: String {
        switch self {
        case .json: return "json"
        case .csv: return "csv"
        case .markdown: return "md"
        case .xlsx: return "xlsx"
        }
    }
}

/// Represents a recent export operation
public struct RecentExport: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let filePath: String
    public let fileType: ExportFileType
    public let timestamp: Date

    public init(id: UUID = UUID(), filePath: String, fileType: ExportFileType, timestamp: Date = Date()) {
        self.id = id
        self.filePath = filePath
        self.fileType = fileType
        self.timestamp = timestamp
    }

    /// File name without path
    public var fileName: String {
        (filePath as NSString).lastPathComponent
    }

    /// Parent directory path
    public var directoryPath: String {
        (filePath as NSString).deletingLastPathComponent
    }

    /// Check if the file still exists
    public var fileExists: Bool {
        FileManager.default.fileExists(atPath: filePath)
    }
}
