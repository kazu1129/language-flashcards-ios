import SwiftUI
import UIKit

enum DeckExportFormat: String, CaseIterable, Identifiable {
    case text
    case csv
    case pdf

    var id: String { rawValue }

    var title: String {
        switch self {
        case .text:
            "TXT"
        case .csv:
            "CSV"
        case .pdf:
            "PDF"
        }
    }

    var fileExtension: String {
        switch self {
        case .text:
            "txt"
        case .csv:
            "csv"
        case .pdf:
            "pdf"
        }
    }
}

enum DeckExporter {
    static func export(deck: FlashcardDeck, format: DeckExportFormat) throws -> URL {
        let safeName = deck.name.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(safeName)-flashcards")
            .appendingPathExtension(format.fileExtension)

        switch format {
        case .text:
            try exportText(deck: deck, to: url)
        case .csv:
            try exportCSV(deck: deck, to: url)
        case .pdf:
            try exportPDF(deck: deck, to: url)
        }
        return url
    }

    private static func exportText(deck: FlashcardDeck, to url: URL) throws {
        var lines: [String] = []
        lines.append(deck.name)
        lines.append("\(deck.languageOneName) / \(deck.languageTwoName)")
        lines.append("")

        for (index, card) in deck.sortedCards.enumerated() {
            lines.append("\(index + 1). \(card.languageOneText)")
            lines.append("   \(deck.languageTwoName): \(card.languageTwoText)")
            for meaning in card.meanings {
                lines.append("   - \(meaning.meaning)")
                if !meaning.example.isEmpty {
                    lines.append("     Example: \(meaning.example)")
                }
                if !meaning.exampleTranslation.isEmpty {
                    lines.append("     Translation: \(meaning.exampleTranslation)")
                }
            }
            lines.append("")
        }

        try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
    }

    private static func exportCSV(deck: FlashcardDeck, to url: URL) throws {
        var rows: [[String]] = [
            ["英語", "日本語", "それ以外の意味", "英語例文", "日本語例文"]
        ]

        for card in deck.sortedCards {
            let japanese = card.languageOneText
            let english = card.languageTwoText
            let otherMeanings = card.meanings
                .map(\.meaning)
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .filter { !isSameMeaning($0, as: japanese) }
                .joined(separator: " / ")
            let englishExamples = card.meanings
                .map(\.example)
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .joined(separator: " / ")
            let japaneseExamples = card.meanings
                .map(\.exampleTranslation)
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .joined(separator: " / ")

            rows.append([english, japanese, otherMeanings, englishExamples, japaneseExamples])
        }

        let csv = rows.map { row in
            row.map(escapeCSVField).joined(separator: ",")
        }
        .joined(separator: "\n")

        try csv.write(to: url, atomically: true, encoding: .utf8)
    }

    private static func exportPDF(deck: FlashcardDeck, to url: URL) throws {
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        try renderer.writePDF(to: url) { context in
            context.beginPage()
            var y: CGFloat = 36
            let margin: CGFloat = 36
            let width = pageRect.width - margin * 2

            func draw(_ text: String, font: UIFont, color: UIColor = .label, spacing: CGFloat = 8) {
                let paragraph = NSMutableParagraphStyle()
                paragraph.lineBreakMode = .byWordWrapping
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: color,
                    .paragraphStyle: paragraph
                ]
                let rect = NSString(string: text).boundingRect(
                    with: CGSize(width: width, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: attributes,
                    context: nil
                )
                if y + ceil(rect.height) > pageRect.height - margin {
                    context.beginPage()
                    y = margin
                }
                NSString(string: text).draw(
                    with: CGRect(x: margin, y: y, width: width, height: ceil(rect.height)),
                    options: [.usesLineFragmentOrigin, .usesFontLeading],
                    attributes: attributes,
                    context: nil
                )
                y += ceil(rect.height) + spacing
            }

            draw(deck.name, font: .boldSystemFont(ofSize: 24), spacing: 4)
            draw("\(deck.languageOneName) / \(deck.languageTwoName)", font: .systemFont(ofSize: 14), color: .secondaryLabel, spacing: 18)

            for (index, card) in deck.sortedCards.enumerated() {
                draw("\(index + 1). \(card.languageOneText)", font: .boldSystemFont(ofSize: 16), spacing: 4)
                if !card.languageTwoText.isEmpty {
                    draw("\(deck.languageTwoName): \(card.languageTwoText)", font: .systemFont(ofSize: 14), spacing: 6)
                }
                for meaning in card.meanings {
                    draw("Meaning: \(meaning.meaning)", font: .systemFont(ofSize: 13), spacing: 3)
                    if !meaning.example.isEmpty {
                        draw("Example: \(meaning.example)", font: .italicSystemFont(ofSize: 13), spacing: 3)
                    }
                    if !meaning.exampleTranslation.isEmpty {
                        draw("Translation: \(meaning.exampleTranslation)", font: .systemFont(ofSize: 12), color: .secondaryLabel, spacing: 6)
                    }
                }
                y += 8
            }
        }
    }

    private static func escapeCSVField(_ field: String) -> String {
        let needsQuotes = field.contains(",") ||
            field.contains("\"") ||
            field.contains("\n") ||
            field.contains("\r")
        let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
        return needsQuotes ? "\"\(escaped)\"" : escaped
    }

    private static func isSameMeaning(_ left: String, as right: String) -> Bool {
        normalize(left) == normalize(right)
    }

    private static func normalize(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .lowercased()
    }
}
