import Foundation

struct TextImportParseResult {
    var parsedRows: [TextImportParsedRow]
    var rejectedRows: [TextImportRejectedRow]
}

struct TextImportParsedRow: Identifiable, Hashable {
    var id: String
    var rawLine: String
    var languageOne: String
    var languageTwo: String
    var englishTerm: String
    var note: String
}

struct TextImportRejectedRow: Identifiable, Hashable {
    var id: String
    var text: String
    var reason: String
}

enum TextImportParser {
    static func parse(_ text: String) -> TextImportParseResult {
        var parsedRows: [TextImportParsedRow] = []
        var rejectedRows: [TextImportRejectedRow] = []

        let lines = text
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for (index, line) in lines.enumerated() {
            switch parseLine(line, index: index) {
            case .parsed(let row):
                parsedRows.append(row)
            case .rejected(let row):
                rejectedRows.append(row)
            }
        }

        return TextImportParseResult(parsedRows: parsedRows, rejectedRows: rejectedRows)
    }

    static func containsEnglish(_ text: String) -> Bool {
        text.range(of: #"[A-Za-z]"#, options: .regularExpression) != nil
    }

    private static func parseLine(_ line: String, index: Int) -> ParseLineResult {
        let parts = splitLine(line)
        guard let englishPart = parts.first(where: containsEnglish) else {
            return .rejected(
                TextImportRejectedRow(
                    id: "\(index)-rejected",
                    text: line,
                    reason: "英語のword/phraseとして認識できなかったため、保存対象から外しました。"
                )
            )
        }

        let counterpart = parts.first { part in
            part != englishPart && !containsEnglish(part)
        }

        if let counterpart, !counterpart.isEmpty {
            return .parsed(
                TextImportParsedRow(
                    id: "\(index)-parsed",
                    rawLine: line,
                    languageOne: counterpart,
                    languageTwo: englishPart,
                    englishTerm: englishPart,
                    note: "第1言語と第2言語をペアで登録します。"
                )
            )
        }

        return .parsed(
                TextImportParsedRow(
                    id: "\(index)-parsed",
                    rawLine: line,
                    languageOne: englishPart,
                    languageTwo: englishPart,
                    englishTerm: englishPart,
                    note: "英語のみ読み取れたため、第1言語も同じ内容で仮登録します。必要に応じて編集してください。"
                )
            )
    }

    private static func splitLine(_ line: String) -> [String] {
        let csvParts = parseCSVFields(line)
        if csvParts.count >= 2 {
            return csvParts
        }

        let delimiters = ["\t", " -> ", "->", " - ", " — ", " – ", "/", "／", ":", "："]
        for delimiter in delimiters {
            if let range = line.range(of: delimiter) {
                let first = String(line[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                let second = String(line[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                return [first, second].filter { !$0.isEmpty }
            }
        }

        if let englishRange = line.range(of: #"[A-Za-z][A-Za-z0-9 .,'’!?-]*"#, options: .regularExpression) {
            let english = String(line[englishRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            let before = String(line[..<englishRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            let after = String(line[englishRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            let other = [before, after].filter { !$0.isEmpty }.joined(separator: " ")
            if !other.isEmpty {
                return [other, english].filter { !$0.isEmpty }
            }
        }

        return [line]
    }

    private static func parseCSVFields(_ line: String) -> [String] {
        guard line.contains(",") || line.contains("，") else { return [line] }

        var fields: [String] = []
        var current = ""
        var isInsideQuotes = false
        let characters = Array(line)
        var index = 0

        while index < characters.count {
            let character = characters[index]
            if character == "\"" {
                if isInsideQuotes,
                   index + 1 < characters.count,
                   characters[index + 1] == "\"" {
                    current.append("\"")
                    index += 1
                } else {
                    isInsideQuotes.toggle()
                }
            } else if (character == "," || character == "，"), !isInsideQuotes {
                fields.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
                current = ""
            } else {
                current.append(character)
            }
            index += 1
        }

        fields.append(current.trimmingCharacters(in: .whitespacesAndNewlines))
        return fields.filter { !$0.isEmpty }
    }
}

private enum ParseLineResult {
    case parsed(TextImportParsedRow)
    case rejected(TextImportRejectedRow)
}
