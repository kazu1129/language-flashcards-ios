import SwiftData
import SwiftUI
import UIKit
import XCTest
@testable import LanguageFlashcards

@MainActor
final class StudySessionCardEditingTests: XCTestCase {
    func testEditingOnlyCardPersistsAndPreservesStudyMemory() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let reviewedAt = Date(timeIntervalSince1970: 1_750_000_000)
        let savedAt = reviewedAt.addingTimeInterval(600)
        let card = Flashcard(languageOneText: "誤字", languageTwoText: "wrnog")
        _ = card.registerReview(.unsure, at: reviewedAt)
        let deck = FlashcardDeck(name: "編集テスト", cards: [card])
        context.insert(deck)
        try context.save()

        let sessionCards = [card]
        let currentIndex = 0
        let ratedCardIDs: Set<UUID> = [card.id]
        let reviewSnapshot = ReviewSnapshot(card: card)
        let meaning = MeaningEntry(
            meaning: "正しい意味",
            synonyms: "correct",
            example: "This is correct.",
            exampleTranslation: "これは正しい。"
        )

        CardEditorSaveOperation.updateExistingCard(
            card,
            in: deck,
            languageOneText: "修正済み",
            languageTwoText: "correct",
            meanings: [meaning],
            savedAt: savedAt
        )
        try context.save()

        XCTAssertEqual(currentIndex, 0)
        XCTAssertEqual(sessionCards[currentIndex].id, card.id)
        XCTAssertEqual(sessionCards[currentIndex].languageOneText, "修正済み")
        XCTAssertEqual(sessionCards[currentIndex].languageTwoText, "correct")
        XCTAssertEqual(sessionCards[currentIndex].meanings, [meaning])
        XCTAssertEqual(ratedCardIDs, [card.id])
        XCTAssertEqual(card.updatedAt, savedAt)
        XCTAssertEqual(deck.updatedAt, savedAt)
        reviewSnapshot.assertUnchanged(card, file: #filePath, line: #line)

        let persistedCard = try XCTUnwrap(
            context.fetch(FetchDescriptor<Flashcard>()).first { $0.id == card.id }
        )
        XCTAssertEqual(persistedCard.languageOneText, "修正済み")
        XCTAssertEqual(persistedCard.languageTwoText, "correct")
        reviewSnapshot.assertUnchanged(persistedCard, file: #filePath, line: #line)
    }

    func testEditingFirstAndLastCardsDoesNotReorderActiveSession() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let createdAt = Date(timeIntervalSince1970: 1_750_000_000)
        let first = Flashcard(languageOneText: "先頭", createdAt: createdAt)
        let middle = Flashcard(languageOneText: "中央", createdAt: createdAt.addingTimeInterval(1))
        let last = Flashcard(languageOneText: "末尾", createdAt: createdAt.addingTimeInterval(2))
        let deck = FlashcardDeck(name: "境界テスト", cards: [last, first, middle])
        context.insert(deck)
        try context.save()

        let sessionCards = deck.sortedCards
        let originalOrder = sessionCards.map(\.id)
        var currentIndex = 0

        CardEditorSaveOperation.updateExistingCard(
            sessionCards[currentIndex],
            in: deck,
            languageOneText: "先頭を修正",
            languageTwoText: "first",
            meanings: []
        )
        XCTAssertEqual(currentIndex, 0)
        XCTAssertEqual(sessionCards.map(\.id), originalOrder)
        XCTAssertEqual(sessionCards[currentIndex].languageOneText, "先頭を修正")

        currentIndex = sessionCards.count - 1
        CardEditorSaveOperation.updateExistingCard(
            sessionCards[currentIndex],
            in: deck,
            languageOneText: "末尾を修正",
            languageTwoText: "last",
            meanings: []
        )
        try context.save()

        XCTAssertEqual(currentIndex, 2)
        XCTAssertEqual(sessionCards.map(\.id), originalOrder)
        XCTAssertEqual(sessionCards[currentIndex].languageOneText, "末尾を修正")
        XCTAssertEqual(deck.cards.count, 3)
    }

    func testStudySessionAndExistingEditorLoadAtZeroAndOneCardBoundaries() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let card = Flashcard(languageOneText: "猫", languageTwoText: "cat")
        let emptyDeck = FlashcardDeck(name: "0枚")
        let singleCardDeck = FlashcardDeck(name: "1枚", cards: [card])
        context.insert(emptyDeck)
        context.insert(singleCardDeck)

        let suiteName = "StudySessionCardEditingTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = AppSettings(defaults: defaults)

        for deck in [emptyDeck, singleCardDeck] {
            let host = UIHostingController(
                rootView: NavigationStack {
                    StudySessionView(deck: deck)
                }
                .environmentObject(settings)
                .modelContainer(container)
            )
            host.loadViewIfNeeded()
            host.view.layoutIfNeeded()
            XCTAssertNotNil(host.view)
        }

        let editorHost = UIHostingController(
            rootView: NavigationStack {
                CardEditorView(deck: singleCardDeck, card: card, totalCardCount: 1)
            }
            .environmentObject(settings)
            .modelContainer(container)
        )
        editorHost.loadViewIfNeeded()
        editorHost.view.layoutIfNeeded()
        XCTAssertNotNil(editorHost.view)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            FlashcardDeck.self,
            Flashcard.self,
            StudyReview.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}

private struct ReviewSnapshot {
    let lastReviewedAt: Date?
    let dueAt: Date
    let intervalDays: Double
    let easeFactor: Double
    let fsrsDifficulty: Double?
    let fsrsStability: Double?
    let lastRating: ReviewRating?
    let reviewCount: Int
    let perfectCount: Int
    let unsureCount: Int
    let unknownCount: Int
    let promotedToPerfectCount: Int

    init(card: Flashcard) {
        lastReviewedAt = card.lastReviewedAt
        dueAt = card.dueAt
        intervalDays = card.intervalDays
        easeFactor = card.easeFactor
        fsrsDifficulty = card.fsrsDifficulty
        fsrsStability = card.fsrsStability
        lastRating = card.lastRating
        reviewCount = card.reviewCount
        perfectCount = card.perfectCount
        unsureCount = card.unsureCount
        unknownCount = card.unknownCount
        promotedToPerfectCount = card.promotedToPerfectCount
    }

    func assertUnchanged(
        _ card: Flashcard,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(card.lastReviewedAt, lastReviewedAt, file: file, line: line)
        XCTAssertEqual(card.dueAt, dueAt, file: file, line: line)
        XCTAssertEqual(card.intervalDays, intervalDays, file: file, line: line)
        XCTAssertEqual(card.easeFactor, easeFactor, file: file, line: line)
        XCTAssertEqual(card.fsrsDifficulty, fsrsDifficulty, file: file, line: line)
        XCTAssertEqual(card.fsrsStability, fsrsStability, file: file, line: line)
        XCTAssertEqual(card.lastRating, lastRating, file: file, line: line)
        XCTAssertEqual(card.reviewCount, reviewCount, file: file, line: line)
        XCTAssertEqual(card.perfectCount, perfectCount, file: file, line: line)
        XCTAssertEqual(card.unsureCount, unsureCount, file: file, line: line)
        XCTAssertEqual(card.unknownCount, unknownCount, file: file, line: line)
        XCTAssertEqual(card.promotedToPerfectCount, promotedToPerfectCount, file: file, line: line)
    }
}
