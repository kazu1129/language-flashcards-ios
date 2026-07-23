import Foundation
import Testing
@testable import LanguageFlashcards

@MainActor
struct LocalizationCatalogTests {
    private let p0Keys = [
        "%@ / %@ ・ %lld枚",
        "CSV/TXTを読み込む",
        "セットを追加",
        "ファイルから追加",
        "フラッシュカードセット",
        "フラッシュカードセットがありません",
        "ホーム",
        "先にフラッシュカードセットを作ると、CSV/TXTからカードを追加できます。",
        "先にフラッシュカードセットを作ると、写真からカードを追加できます。",
        "写真を撮る",
        "写真を選ぶ",
        "右上の追加ボタンから、最初のセットを作れます。",
        "成果",
        "設定",
        "追加",
        "追加先のセット",
        "追加先のセットがありません",
        "閉じる",
    ]

    @Test("英語カタログはタブ3項目を翻訳する")
    func resolvesEnglishTabTranslations() throws {
        // 狙い: 英語リソースがアプリへ組み込まれ、主要タブが指定訳で解決されることを直接証明する。
        let translations = try compiledTranslations(for: "en")

        #expect(translations["ホーム"] == "Home")
        #expect(translations["成果"] == "Progress")
        #expect(translations["設定"] == "Settings")
    }

    @Test("日本語ソースは既存表示を維持する")
    func preservesJapaneseSourceStrings() throws {
        // 狙い: 日本語ソース言語は翻訳テーブルではなくキーへのフォールバックで表示される設計を検証し、既存の日本語表示の退行を防ぐ。
        let preferredLocalizations = Bundle.preferredLocalizations(
            from: Bundle.main.localizations,
            forPreferences: ["ja"]
        )
        let japaneseResourcePath = Bundle.main.path(
            forResource: "Localizable",
            ofType: "strings",
            inDirectory: nil,
            forLocalization: "ja"
        )

        #expect(Bundle.main.developmentLocalization == "ja")
        #expect(preferredLocalizations.first == "ja")
        #expect(japaneseResourcePath == nil)

        if japaneseResourcePath != nil {
            let translations = try compiledTranslations(for: "ja")
            for key in p0Keys {
                #expect(translations[key] == key)
            }
        }
    }

    @Test("P0対象キーは英語訳を全件持つ")
    func coversEveryP0KeyInEnglish() throws {
        // 狙い: RootViewとHomeViewのP0キーに未訳・空訳・キーのタイプミスがないことを検知する。
        let translations = try compiledTranslations(for: "en")

        for key in p0Keys {
            let translation = translations[key]
            #expect(translation?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
        }
    }

    @Test("カード枚数の英訳は全プレースホルダを保持する")
    func preservesInterpolationPlaceholders() throws {
        // 狙い: 言語名2件と枚数の引数順を固定し、実行時のフォーマット不整合やクラッシュを防ぐ。
        let translations = try compiledTranslations(for: "en")
        let translation = try #require(translations["%@ / %@ ・ %lld枚"])

        #expect(translation.contains("%1$@"))
        #expect(translation.contains("%2$@"))
        #expect(translation.contains("%3$lld"))
    }

    private func compiledTranslations(for localization: String) throws -> [String: String] {
        let resourcePath = try #require(
            Bundle.main.path(
                forResource: "Localizable",
                ofType: "strings",
                inDirectory: nil,
                forLocalization: localization
            )
        )
        let data = try Data(contentsOf: URL(fileURLWithPath: resourcePath))
        let propertyList = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try #require(propertyList as? [String: String])
    }
}
