import Foundation

/// Represents a recent export operation
struct RecentExport: Identifiable, Codable, Equatable {
    let id: UUID
    let filePath: String
    let fileType: ExportFileType
    let timestamp: Date

    init(filePath: String, fileType: ExportFileType) {
        self.id = UUID()
        self.filePath = filePath
        self.fileType = fileType
        self.timestamp = Date()
    }

    /// File name without path
    var fileName: String {
        (filePath as NSString).lastPathComponent
    }

    /// Parent directory path
    var directoryPath: String {
        (filePath as NSString).deletingLastPathComponent
    }

    /// Check if the file still exists
    var fileExists: Bool {
        FileManager.default.fileExists(atPath: filePath)
    }
}

/// Supported export file types
enum ExportFileType: String, Codable, CaseIterable {
    case json
    case csv
    case markdown
    case xlsx

    var displayName: String {
        switch self {
        case .json: return "JSON"
        case .csv: return "CSV"
        case .markdown: return "Markdown"
        case .xlsx: return "Excel"
        }
    }

    var icon: String {
        switch self {
        case .json: return "curlybraces"
        case .csv: return "tablecells"
        case .markdown: return "text.document"
        case .xlsx: return "tablecells.badge.ellipsis"
        }
    }

    var fileExtension: String {
        switch self {
        case .json: return "json"
        case .csv: return "csv"
        case .markdown: return "md"
        case .xlsx: return "xlsx"
        }
    }
}
