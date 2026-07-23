import Foundation
import Testing
import Vision
@testable import LanguageFlashcards

struct OCRServiceTests {
    @Test("OCRは日本語を優先し英語も認識する")
    func prioritizesJapaneseRecognition() {
        // 狙い: 日本語を先頭に固定し、日本語中心の画像で英語既定値へ偏る退行を防ぐ。
        let request = OCRService.configuredRequest()

        #expect(request.recognitionLanguages == ["ja-JP", "en-US"])
    }

    @Test("OCRは高精度認識を維持する")
    func preservesAccurateRecognitionLevel() {
        // 狙い: 設定抽出後も既存の高精度OCRモードが低下しないことを確認する。
        let request = OCRService.configuredRequest()

        #expect(request.recognitionLevel == .accurate)
    }

    @Test("OCRは言語補正を維持する")
    func preservesLanguageCorrection() {
        // 狙い: 設定抽出後も既存の言語補正が有効なままであることを確認する。
        let request = OCRService.configuredRequest()

        #expect(request.usesLanguageCorrection)
    }

    @Test("OCR言語設定に重複と空文字がない")
    func keepsRecognitionLanguagesHealthy() {
        // 狙い: 言語追加時の重複や空値でVisionの設定品質が崩れないことを担保する。
        let languages = OCRService.configuredRequest().recognitionLanguages

        #expect(languages.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
        #expect(Set(languages).count == languages.count)
    }
}
