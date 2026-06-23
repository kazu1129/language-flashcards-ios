import Foundation

struct MeaningEntry: Identifiable, Codable, Hashable {
    var id: UUID
    var meaning: String
    var synonyms: String
    var example: String
    var exampleTranslation: String

    init(id: UUID = UUID(), meaning: String = "", synonyms: String = "", example: String = "", exampleTranslation: String = "") {
        self.id = id
        self.meaning = meaning
        self.synonyms = synonyms
        self.example = example
        self.exampleTranslation = exampleTranslation
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case meaning
        case synonyms
        case example
        case exampleTranslation
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.meaning = try container.decodeIfPresent(String.self, forKey: .meaning) ?? ""
        self.synonyms = try container.decodeIfPresent(String.self, forKey: .synonyms) ?? ""
        self.example = try container.decodeIfPresent(String.self, forKey: .example) ?? ""
        self.exampleTranslation = try container.decodeIfPresent(String.self, forKey: .exampleTranslation) ?? ""
    }

    static func decode(from json: String) -> [MeaningEntry] {
        guard let data = json.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([MeaningEntry].self, from: data)) ?? []
    }

    static func encode(_ entries: [MeaningEntry]) -> String {
        guard let data = try? JSONEncoder().encode(entries) else { return "[]" }
        return String(data: data, encoding: .utf8) ?? "[]"
    }
}
