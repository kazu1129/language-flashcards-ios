import Foundation
import SwiftData
import Testing
@testable import LanguageFlashcards

@MainActor
struct CardEditorDeleteTests {
    @Test("カード削除は対象だけを消す")
    func deletesOnlyTheSelectedCard() throws {
        // 狙い: 編集画面の削除が対象カードだけを消し、同じデッキの別カードを残すことを担保する。
        let container = try makeContainer()
        let context = container.mainContext
        let target = Flashcard(languageOneText: "共依存の", languageTwoText: "codependent on")
        let survivor = Flashcard(languageOneText: "猫", languageTwoText: "cat")
        let deck = FlashcardDeck(name: "英語", cards: [target, survivor])
        context.insert(deck)
        try context.save()

        #expect(CardEditorDeleteOperation.delete(card: target, from: deck, in: context))

        let remainingIDs = try context.fetch(FetchDescriptor<Flashcard>()).map(\.id)
        #expect(!remainingIDs.contains(target.id))
        #expect(remainingIDs.contains(survivor.id))
        #expect(remainingIDs.count == 1)
    }

    @Test("カード削除はデッキ更新日時を進める")
    func updatesDeckTimestamp() throws {
        // 狙い: 一覧の並びと更新日表示に使う既存の deck.updatedAt 更新作法を維持する。
        let container = try makeContainer()
        let context = container.mainContext
        let oldDate = Date(timeIntervalSince1970: 1_700_000_000)
        let deletedAt = oldDate.addingTimeInterval(60)
        let card = Flashcard(languageOneText: "共依存の", languageTwoText: "codependent on")
        let deck = FlashcardDeck(name: "英語", updatedAt: oldDate, cards: [card])
        context.insert(deck)
        try context.save()

        CardEditorDeleteOperation.delete(
            card: card,
            from: deck,
            in: context,
            at: deletedAt
        )

        #expect(deck.updatedAt == deletedAt)
        #expect(deck.updatedAt > oldDate)
    }

    @Test("削除導線は編集モードだけで有効")
    func exposesDeleteOnlyWhileEditing() {
        // 狙い: 新規追加画面に削除ボタンが漏れず、編集対象がある場合だけ表示される条件を固定する。
        let existingCard = Flashcard(languageOneText: "共依存の", languageTwoText: "codependent on")

        #expect(CardEditorDeleteOperation.canDelete(card: existingCard))
        #expect(!CardEditorDeleteOperation.canDelete(card: nil))
    }

    @Test("カード削除は既存の学習履歴を付随削除しない")
    func preservesExistingStudyReview() throws {
        // 狙い: DeckDetailView と同じ既存仕様を踏襲し、StudyReview の新たな連鎖削除を持ち込まない。
        let container = try makeContainer()
        let context = container.mainContext
        let card = Flashcard(languageOneText: "共依存の", languageTwoText: "codependent on")
        let deck = FlashcardDeck(name: "英語", cards: [card])
        let review = StudyReview(
            deckID: deck.id,
            cardID: card.id,
            deckName: deck.name,
            cardText: card.languageOneText,
            rating: .unknown,
            previousRating: nil,
            promotedToPerfect: false
        )
        context.insert(deck)
        context.insert(review)
        try context.save()

        CardEditorDeleteOperation.delete(card: card, from: deck, in: context)

        let reviews = try context.fetch(FetchDescriptor<StudyReview>())
        #expect(reviews.count == 1)
        #expect(reviews.first?.cardID == card.id)
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
