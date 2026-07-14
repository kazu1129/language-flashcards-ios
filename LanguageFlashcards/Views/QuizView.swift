import SwiftUI

struct QuizView: View {
    var body: some View {
        ContentUnavailableView(
            "準備中",
            systemImage: "questionmark.circle",
            description: Text("クイズモードは準備中です。")
        )
        .navigationTitle("クイズ")
        .navigationBarTitleDisplayMode(.inline)
    }
}
