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
            String(localized: "reviewRating.title.perfect")
        case .unsure:
            String(localized: "reviewRating.title.unsure")
        case .unknown:
            String(localized: "reviewRating.title.unknown")
        }
    }

    var shortTitle: String {
        switch self {
        case .perfect:
            String(localized: "reviewRating.short.perfect")
        case .unsure:
            String(localized: "reviewRating.short.unsure")
        case .unknown:
            String(localized: "reviewRating.short.unknown")
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
