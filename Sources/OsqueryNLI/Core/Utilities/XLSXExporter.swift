import Foundation

/// Exports QueryResult to XLSX (Excel) format without external dependencies
/// XLSX is a ZIP archive containing XML files following the Office Open XML standard
enum XLSXExporter {

    /// Export QueryResult to XLSX data
    static func export(result: QueryResult) -> Data? {
        guard !result.columns.isEmpty else { return nil }

        // Create the XML content files
        let sheetXML = createSheetXML(result: result)
        let workbookXML = createWorkbookXML()
        let stylesXML = createStylesXML()
        let contentTypesXML = createContentTypesXML()
        let relsXML = createRelsXML()
        let workbookRelsXML = createWorkbookRelsXML()
        let sharedStringsXML = createSharedStringsXML(result: result)

        // Create ZIP archive
        return createZIPArchive(files: [
            "[Content_Types].xml": contentTypesXML,
            "_rels/.rels": relsXML,
            "xl/_rels/workbook.xml.rels": workbookRelsXML,
            "xl/workbook.xml": workbookXML,
            "xl/styles.xml": stylesXML,
            "xl/sharedStrings.xml": sharedStringsXML,
            "xl/worksheets/sheet1.xml": sheetXML
        ])
    }

    // MARK: - XML Generation

    private static func createSheetXML(result: QueryResult) -> String {
        var xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
        <sheetData>
        """

        // Header row (row 1)
        xml += "<row r=\"1\">"
        for (colIndex, column) in result.columns.enumerated() {
            let cellRef = cellReference(row: 1, col: colIndex)
            let escapedName = escapeXML(column.name)
            xml += "<c r=\"\(cellRef)\" t=\"inlineStr\" s=\"1\"><is><t>\(escapedName)</t></is></c>"
        }
        xml += "</row>"

        // Data rows
        for (rowIndex, row) in result.rows.enumerated() {
            let excelRow = rowIndex + 2 // Excel rows are 1-indexed, +1 for header
            xml += "<row r=\"\(excelRow)\">"
            for (colIndex, column) in result.columns.enumerated() {
                let cellRef = cellReference(row: excelRow, col: colIndex)
                let value = row[column.name] ?? ""
                let escapedValue = escapeXML(value)

                // Check if value is numeric
                if let _ = Double(value) {
                    xml += "<c r=\"\(cellRef)\"><v>\(value)</v></c>"
                } else {
                    xml += "<c r=\"\(cellRef)\" t=\"inlineStr\"><is><t>\(escapedValue)</t></is></c>"
                }
            }
            xml += "</row>"
        }

        xml += """
        </sheetData>
        </worksheet>
        """

        return xml
    }

    private static func createWorkbookXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
        <sheets>
        <sheet name="Query Results" sheetId="1" r:id="rId1"/>
        </sheets>
        </workbook>
        """
    }

    private static func createStylesXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
        <fonts count="2">
        <font><sz val="11"/><name val="Calibri"/></font>
        <font><b/><sz val="11"/><name val="Calibri"/></font>
        </fonts>
        <fills count="2">
        <fill><patternFill patternType="none"/></fill>
        <fill><patternFill patternType="gray125"/></fill>
        </fills>
        <borders count="1">
        <border><left/><right/><top/><bottom/><diagonal/></border>
        </borders>
        <cellStyleXfs count="1">
        <xf numFmtId="0" fontId="0" fillId="0" borderId="0"/>
        </cellStyleXfs>
        <cellXfs count="2">
        <xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>
        <xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>
        </cellXfs>
        </styleSheet>
        """
    }

    private static func createContentTypesXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
        <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
        <Default Extension="xml" ContentType="application/xml"/>
        <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
        <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
        <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
        <Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>
        </Types>
        """
    }

    private static func createRelsXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
        </Relationships>
        """
    }

    private static func createWorkbookRelsXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
        <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
        <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings" Target="sharedStrings.xml"/>
        </Relationships>
        """
    }

    private static func createSharedStringsXML(result: QueryResult) -> String {
        // Empty shared strings - we use inline strings instead
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="0" uniqueCount="0">
        </sst>
        """
    }

    // MARK: - Helpers

    private static func cellReference(row: Int, col: Int) -> String {
        // Convert column index to Excel column letters (0=A, 1=B, ..., 25=Z, 26=AA, etc.)
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        var colLetters = ""
        var colNum = col
        repeat {
            let index = letters.index(letters.startIndex, offsetBy: colNum % 26)
            colLetters = String(letters[index]) + colLetters
            colNum = colNum / 26 - 1
        } while colNum >= 0

        return "\(colLetters)\(row)"
    }

    private static func escapeXML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    // MARK: - ZIP Creation

    private static func createZIPArchive(files: [String: String]) -> Data? {
        var zipData = Data()

        var centralDirectory = Data()
        var fileOffset: UInt32 = 0
        var fileCount: UInt16 = 0

        for (path, content) in files.sorted(by: { $0.key < $1.key }) {
            guard let contentData = content.data(using: .utf8) else { continue }

            let pathData = path.data(using: .utf8)!

            // Local file header
            var localHeader = Data()
            localHeader.append(contentsOf: [0x50, 0x4B, 0x03, 0x04]) // Local file header signature
            localHeader.append(contentsOf: [0x14, 0x00]) // Version needed (2.0)
            localHeader.append(contentsOf: [0x00, 0x00]) // General purpose bit flag
            localHeader.append(contentsOf: [0x00, 0x00]) // Compression method (stored)
            localHeader.append(contentsOf: [0x00, 0x00]) // Last mod file time
            localHeader.append(contentsOf: [0x00, 0x00]) // Last mod file date
            localHeader.append(contentsOf: crc32(contentData)) // CRC-32
            localHeader.append(contentsOf: uint32LE(UInt32(contentData.count))) // Compressed size
            localHeader.append(contentsOf: uint32LE(UInt32(contentData.count))) // Uncompressed size
            localHeader.append(contentsOf: uint16LE(UInt16(pathData.count))) // File name length
            localHeader.append(contentsOf: [0x00, 0x00]) // Extra field length

            localHeader.append(pathData) // File name
            localHeader.append(contentData) // File data

            // Central directory entry
            var cdEntry = Data()
            cdEntry.append(contentsOf: [0x50, 0x4B, 0x01, 0x02]) // Central directory signature
            cdEntry.append(contentsOf: [0x14, 0x00]) // Version made by
            cdEntry.append(contentsOf: [0x14, 0x00]) // Version needed
            cdEntry.append(contentsOf: [0x00, 0x00]) // General purpose bit flag
            cdEntry.append(contentsOf: [0x00, 0x00]) // Compression method
            cdEntry.append(contentsOf: [0x00, 0x00]) // Last mod file time
            cdEntry.append(contentsOf: [0x00, 0x00]) // Last mod file date
            cdEntry.append(contentsOf: crc32(contentData)) // CRC-32
            cdEntry.append(contentsOf: uint32LE(UInt32(contentData.count))) // Compressed size
            cdEntry.append(contentsOf: uint32LE(UInt32(contentData.count))) // Uncompressed size
            cdEntry.append(contentsOf: uint16LE(UInt16(pathData.count))) // File name length
            cdEntry.append(contentsOf: [0x00, 0x00]) // Extra field length
            cdEntry.append(contentsOf: [0x00, 0x00]) // File comment length
            cdEntry.append(contentsOf: [0x00, 0x00]) // Disk number start
            cdEntry.append(contentsOf: [0x00, 0x00]) // Internal file attributes
            cdEntry.append(contentsOf: [0x00, 0x00, 0x00, 0x00]) // External file attributes
            cdEntry.append(contentsOf: uint32LE(fileOffset)) // Relative offset of local header
            cdEntry.append(pathData) // File name

            centralDirectory.append(cdEntry)

            fileOffset += UInt32(localHeader.count)
            zipData.append(localHeader)
            fileCount += 1
        }

        let cdOffset = UInt32(zipData.count)
        zipData.append(centralDirectory)

        // End of central directory record
        var eocd = Data()
        eocd.append(contentsOf: [0x50, 0x4B, 0x05, 0x06]) // End of central directory signature
        eocd.append(contentsOf: [0x00, 0x00]) // Number of this disk
        eocd.append(contentsOf: [0x00, 0x00]) // Disk where central directory starts
        eocd.append(contentsOf: uint16LE(fileCount)) // Number of central directory records on this disk
        eocd.append(contentsOf: uint16LE(fileCount)) // Total number of central directory records
        eocd.append(contentsOf: uint32LE(UInt32(centralDirectory.count))) // Size of central directory
        eocd.append(contentsOf: uint32LE(cdOffset)) // Offset of start of central directory
        eocd.append(contentsOf: [0x00, 0x00]) // Comment length

        zipData.append(eocd)

        return zipData
    }

    private static func uint16LE(_ value: UInt16) -> [UInt8] {
        [UInt8(value & 0xFF), UInt8((value >> 8) & 0xFF)]
    }

    private static func uint32LE(_ value: UInt32) -> [UInt8] {
        [
            UInt8(value & 0xFF),
            UInt8((value >> 8) & 0xFF),
            UInt8((value >> 16) & 0xFF),
            UInt8((value >> 24) & 0xFF)
        ]
    }

    private static func crc32(_ data: Data) -> [UInt8] {
        var crc: UInt32 = 0xFFFFFFFF

        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                if crc & 1 != 0 {
                    crc = (crc >> 1) ^ 0xEDB88320
                } else {
                    crc >>= 1
                }
            }
        }

        crc ^= 0xFFFFFFFF
        return uint32LE(crc)
    }
}
