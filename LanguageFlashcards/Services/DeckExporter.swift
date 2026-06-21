import SwiftUI
import UIKit

enum DeckExportFormat: String, CaseIterable, Identifiable {
    case text
    case pdf

    var id: String { rawValue }

    var title: String {
        switch self {
        case .text:
            "TXT"
        case .pdf:
            "PDF"
        }
    }

    var fileExtension: String {
        switch self {
        case .text:
            "txt"
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
}

