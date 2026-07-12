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
            "\u{65E5}\u{672C}\u{8A9E}": "ja-JP",
            "japanese": "ja-JP",
            "\u{82F1}\u{8A9E}": "en-US",
            "english": "en-US",
            "\u{7C73}\u{8A9E}": "en-US",
            "\u{4E2D}\u{56FD}\u{8A9E}": "zh-CN",
            "chinese": "zh-CN",
            "\u{97D3}\u{56FD}\u{8A9E}": "ko-KR",
            "korean": "ko-KR",
            "\u{30D5}\u{30E9}\u{30F3}\u{30B9}\u{8A9E}": "fr-FR",
            "french": "fr-FR",
            "\u{30B9}\u{30DA}\u{30A4}\u{30F3}\u{8A9E}": "es-ES",
            "spanish": "es-ES",
            "\u{30C9}\u{30A4}\u{30C4}\u{8A9E}": "de-DE",
            "german": "de-DE",
            "\u{30A4}\u{30BF}\u{30EA}\u{30A2}\u{8A9E}": "it-IT",
            "italian": "it-IT",
            "\u{30DD}\u{30EB}\u{30C8}\u{30AC}\u{30EB}\u{8A9E}": "pt-BR",
            "portuguese": "pt-BR"
        ]
        return map[normalized]
    }
}
