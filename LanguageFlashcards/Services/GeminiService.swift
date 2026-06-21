import Foundation

struct GeminiFlashcardSuggestion: Decodable {
    var languageTwoText: String
    var meanings: [MeaningEntry]
}

enum GeminiServiceError: LocalizedError {
    case missingAPIKey
    case invalidModel
    case invalidResponse
    case apiMessage(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "Gemini APIキーが設定されていません。"
        case .invalidModel:
            "Geminiモデル名が正しくありません。"
        case .invalidResponse:
            "Geminiの応答を読み取れませんでした。"
        case .apiMessage(let message):
            message
        }
    }
}

final class GeminiService {
    private struct GenerateRequest: Encodable {
        var contents: [Content]
        var tools: [Tool]?
        var generationConfig: GenerationConfig
    }

    private struct Content: Encodable {
        var parts: [Part]
    }

    private struct Part: Encodable {
        var text: String
    }

    private struct GenerationConfig: Encodable {
        var temperature: Double
        var responseMimeType: String
    }

    private struct Tool: Encodable {
        var googleSearch: GoogleSearch

        private enum CodingKeys: String, CodingKey {
            case googleSearch = "google_search"
        }
    }

    private struct GoogleSearch: Encodable {}

    private struct GenerateResponse: Decodable {
        var candidates: [Candidate]?
        var error: APIError?
    }

    private struct Candidate: Decodable {
        var content: CandidateContent?
    }

    private struct CandidateContent: Decodable {
        var parts: [CandidatePart]?
    }

    private struct CandidatePart: Decodable {
        var text: String?
    }

    private struct APIError: Decodable {
        var message: String
    }

    func completeCard(
        languageOneText: String,
        languageOneName: String,
        languageTwoName: String,
        apiKey: String,
        model: String,
        exampleLanguageName: String? = nil,
        useGoogleSearch: Bool = true
    ) async throws -> GeminiFlashcardSuggestion {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { throw GeminiServiceError.missingAPIKey }

        let cleanModel = model.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "models/", with: "")
        guard let encodedModel = cleanModel.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed), !encodedModel.isEmpty else {
            throw GeminiServiceError.invalidModel
        }

        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(encodedModel):generateContent")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(trimmedKey, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let prompt = """
        You are helping create a language-learning flashcard.
        Return only valid JSON, with no Markdown.

        Source language: \(languageOneName)
        Target language: \(languageTwoName)
        Example sentence language: \(exampleLanguageName ?? languageTwoName)
        Source word or phrase: \(languageOneText)

        JSON schema:
        {
          "languageTwoText": "translation or natural equivalent in the target language",
          "meanings": [
            {
              "meaning": "short meaning in Japanese if possible, otherwise concise explanation",
              "example": "one natural example sentence for this meaning in the target language",
              "exampleTranslation": "translation of the example in the source language"
            }
          ]
        }

        If there are multiple common meanings, include each meaning with exactly one example.
        Use Google Search grounding when it helps make the meaning and example natural and current.
        """

        let body = GenerateRequest(
            contents: [Content(parts: [Part(text: prompt)])],
            tools: useGoogleSearch ? [Tool(googleSearch: GoogleSearch())] : nil,
            generationConfig: GenerationConfig(temperature: 0.2, responseMimeType: "application/json")
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            if let errorResponse = try? JSONDecoder().decode(GenerateResponse.self, from: data), let message = errorResponse.error?.message {
                throw GeminiServiceError.apiMessage(message)
            }
            throw GeminiServiceError.invalidResponse
        }

        let decoded = try JSONDecoder().decode(GenerateResponse.self, from: data)
        guard let text = decoded.candidates?.first?.content?.parts?.compactMap(\.text).joined(), !text.isEmpty else {
            throw GeminiServiceError.invalidResponse
        }

        let jsonText = extractJSON(from: text)
        guard let jsonData = jsonText.data(using: .utf8) else { throw GeminiServiceError.invalidResponse }
        return try JSONDecoder().decode(GeminiFlashcardSuggestion.self, from: jsonData)
    }

    private func extractJSON(from text: String) -> String {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```") {
            cleaned = cleaned
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```JSON", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return cleaned
    }
}
