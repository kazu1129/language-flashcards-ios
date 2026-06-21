import Foundation
import SwiftUI

enum ReviewRating: String, CaseIterable, Codable, Identifiable {
    case perfect
    case unsure
    case unknown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .perfect:
            "完璧"
        case .unsure:
            "まだ自信ない"
        case .unknown:
            "わからなかった"
        }
    }

    var shortTitle: String {
        switch self {
        case .perfect:
            "完璧"
        case .unsure:
            "自信なし"
        case .unknown:
            "不明"
        }
    }

    var tint: Color {
        switch self {
        case .perfect:
            .green
        case .unsure:
            .orange
        case .unknown:
            .red
        }
    }
}

