import Foundation
import Testing
@testable import LanguageFlashcards

@MainActor
struct MeaningRowDeleteTests {
    @Test("ID指定削除は対象の意味行だけを消す")
    func deletesOnlyTheSelectedMeaning() {
        // 狙い: 明示削除ボタンが選択行だけを削除し、別の意味行を保持することを担保する。
        let target = MeaningEntry(meaning: "走る")
        let survivor = MeaningEntry(meaning: "経営する")

        let result = MeaningRowDeleteOperation.delete(
            id: target.id,
            from: [target, survivor]
        )

        #expect(result == [survivor])
    }

    @Test("最後の意味行は削除できない")
    func preservesTheLastMeaning() {
        // 狙い: 2行から1行へ減った後は表示条件と削除処理の両方で最低1行を保証する。
        let first = MeaningEntry(meaning: "速い")
        let last = MeaningEntry(meaning: "時間が早い")
        let oneRemaining = MeaningRowDeleteOperation.delete(
            id: first.id,
            from: [first, last]
        )

        #expect(!MeaningRowDeleteOperation.canDelete(from: oneRemaining))
        #expect(MeaningRowDeleteOperation.delete(id: last.id, from: oneRemaining) == oneRemaining)
    }

    @Test("スワイプで全行削除しても空行を補充する")
    func replenishesAnEmptyMeaningAfterSwipeDelete() {
        // 狙い: onDeleteで最後の行が消えた場合に空のMeaningEntryを1件補う既存挙動を維持する。
        let result = MeaningRowDeleteOperation.delete(
            at: IndexSet(integer: 0),
            from: [MeaningEntry(meaning: "削除対象")]
        )

        #expect(result.count == 1)
        #expect(result[0].meaning.isEmpty)
        #expect(result[0].synonyms.isEmpty)
        #expect(result[0].example.isEmpty)
        #expect(result[0].exampleTranslation.isEmpty)
    }

    @Test("存在しないIDでは意味行を変更しない")
    func ignoresAnUnknownMeaningID() {
        // 狙い: 古いIDや不正なIDが渡されても、入力済みの意味行を誤って失わないことを担保する。
        let meanings = [
            MeaningEntry(meaning: "明るい"),
            MeaningEntry(meaning: "賢い"),
        ]

        #expect(MeaningRowDeleteOperation.delete(id: UUID(), from: meanings) == meanings)
    }
}
