import AVFoundation
import Foundation

@MainActor
final class SpeechService: NSObject, ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String, languageName: String, muted: Bool) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !muted, !trimmed.isEmpty else { return }

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: trimmed)
        if let code = LanguageCodeResolver.code(for: languageName) {
            utterance.voice = AVSpeechSynthesisVoice(language: code)
        }
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}

extension SpeechService: AVSpeechSynthesizerDelegate {}

enum LanguageCodeResolver {
    static func code(for languageName: String) -> String? {
        let normalized = languageName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let map: [String: String] = [
            "日本語": "ja-JP",
            "japanese": "ja-JP",
            "英語": "en-US",
            "english": "en-US",
            "米語": "en-US",
            "中国語": "zh-CN",
            "chinese": "zh-CN",
            "韓国語": "ko-KR",
            "korean": "ko-KR",
            "フランス語": "fr-FR",
            "french": "fr-FR",
            "スペイン語": "es-ES",
            "spanish": "es-ES",
            "ドイツ語": "de-DE",
            "german": "de-DE",
            "イタリア語": "it-IT",
            "italian": "it-IT",
            "ポルトガル語": "pt-BR",
            "portuguese": "pt-BR"
        ]
        return map[normalized]
    }
}

