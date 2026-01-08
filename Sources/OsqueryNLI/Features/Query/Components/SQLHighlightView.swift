import SwiftUI
import AppKit

/// View that displays SQL with syntax highlighting
struct SQLHighlightView: View {
    let sql: String
    @State private var attributedString: AttributedString?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if let highlighted = attributedString {
                Text(highlighted)
                    .textSelection(.enabled)
            } else {
                Text(sql)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(colorScheme == .dark ? Color.black.opacity(0.3) : Color.black.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onAppear {
            highlightSQL()
        }
        .onChange(of: colorScheme) { _, _ in
            highlightSQL()
        }
    }

    private func highlightSQL() {
        Task {
            let highlighted = await generateHighlightedSQL()
            await MainActor.run {
                self.attributedString = highlighted
            }
        }
    }

    private func generateHighlightedSQL() async -> AttributedString? {
        SQLHighlighter.highlight(sql, isDark: colorScheme == .dark)
    }
}

/// Simple SQL syntax highlighter using AttributedString
enum SQLHighlighter {
    // SQL keywords to highlight
    private static let keywords: Set<String> = [
        "SELECT", "FROM", "WHERE", "AND", "OR", "NOT", "IN", "LIKE",
        "ORDER", "BY", "GROUP", "HAVING", "LIMIT", "OFFSET",
        "JOIN", "LEFT", "RIGHT", "INNER", "OUTER", "ON",
        "INSERT", "INTO", "VALUES", "UPDATE", "SET", "DELETE",
        "CREATE", "TABLE", "DROP", "ALTER", "INDEX",
        "AS", "DISTINCT", "ALL", "UNION", "EXCEPT", "INTERSECT",
        "CASE", "WHEN", "THEN", "ELSE", "END",
        "NULL", "IS", "BETWEEN", "EXISTS",
        "COUNT", "SUM", "AVG", "MIN", "MAX",
        "ASC", "DESC", "NULLS", "FIRST", "LAST",
        "TRUE", "FALSE", "WITH", "RECURSIVE"
    ]

    static func highlight(_ sql: String, isDark: Bool) -> AttributedString {
        var result = AttributedString(sql)
        result.font = .system(.body, design: .monospaced)
        result.foregroundColor = isDark ? .white : .black

        let keywordColor: Color = isDark ? .cyan : .blue
        let stringColor: Color = isDark ? .green : Color(red: 0.0, green: 0.5, blue: 0.0)
        let numberColor: Color = isDark ? .orange : Color(red: 0.8, green: 0.4, blue: 0.0)
        let commentColor: Color = .gray

        let sqlLower = sql.lowercased()
        let sqlChars = Array(sql)

        // Highlight SQL keywords
        for keyword in keywords {
            let keywordLower = keyword.lowercased()
            var searchStart = sqlLower.startIndex

            while let range = sqlLower.range(of: keywordLower, range: searchStart..<sqlLower.endIndex) {
                // Check word boundaries
                let beforeOK = range.lowerBound == sqlLower.startIndex ||
                    !sqlLower[sqlLower.index(before: range.lowerBound)].isLetter
                let afterOK = range.upperBound == sqlLower.endIndex ||
                    !sqlLower[range.upperBound].isLetter

                if beforeOK && afterOK {
                    // Convert String range to AttributedString range
                    let startOffset = sqlLower.distance(from: sqlLower.startIndex, to: range.lowerBound)
                    let endOffset = sqlLower.distance(from: sqlLower.startIndex, to: range.upperBound)

                    let attrStart = result.index(result.startIndex, offsetByCharacters: startOffset)
                    let attrEnd = result.index(result.startIndex, offsetByCharacters: endOffset)
                    result[attrStart..<attrEnd].foregroundColor = keywordColor
                }

                searchStart = range.upperBound
            }
        }

        // Highlight strings (single quotes)
        var i = 0
        while i < sqlChars.count {
            if sqlChars[i] == "'" {
                let start = i
                i += 1
                while i < sqlChars.count && sqlChars[i] != "'" {
                    if sqlChars[i] == "\\" && i + 1 < sqlChars.count {
                        i += 2
                    } else {
                        i += 1
                    }
                }
                if i < sqlChars.count {
                    i += 1 // include closing quote
                }
                let end = i

                let attrStart = result.index(result.startIndex, offsetByCharacters: start)
                let attrEnd = result.index(result.startIndex, offsetByCharacters: end)
                result[attrStart..<attrEnd].foregroundColor = stringColor
            } else {
                i += 1
            }
        }

        // Highlight numbers
        i = 0
        while i < sqlChars.count {
            if sqlChars[i].isNumber {
                let start = i
                while i < sqlChars.count && (sqlChars[i].isNumber || sqlChars[i] == ".") {
                    i += 1
                }
                // Check it's not part of an identifier
                let beforeOK = start == 0 || !sqlChars[start - 1].isLetter
                let afterOK = i >= sqlChars.count || !sqlChars[i].isLetter

                if beforeOK && afterOK {
                    let attrStart = result.index(result.startIndex, offsetByCharacters: start)
                    let attrEnd = result.index(result.startIndex, offsetByCharacters: i)
                    result[attrStart..<attrEnd].foregroundColor = numberColor
                }
            } else {
                i += 1
            }
        }

        // Highlight comments (-- style)
        if let commentRange = sql.range(of: "--") {
            let startOffset = sql.distance(from: sql.startIndex, to: commentRange.lowerBound)
            let attrStart = result.index(result.startIndex, offsetByCharacters: startOffset)
            result[attrStart..<result.endIndex].foregroundColor = commentColor
        }

        return result
    }
}

/// Copyable SQL view with highlighting and copy button
struct CopyableSQLView: View {
    let sql: String
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("SQL Query", systemImage: "chevron.left.forwardslash.chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    copyToClipboard()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        Text(copied ? "Copied" : "Copy")
                    }
                    .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            SQLHighlightView(sql: sql)
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(sql, forType: .string)
        copied = true

        Task {
            try? await Task.sleep(for: .seconds(2))
            copied = false
        }
    }
}
