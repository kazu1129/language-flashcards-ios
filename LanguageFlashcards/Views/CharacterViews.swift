import SwiftUI

struct CharacterAvatarView: View {
    var stage: CharacterGrowthStage
    var size: CGFloat = 92

    var body: some View {
        Image(stage.imageName)
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.7), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
    }
}

struct CharacterHomeHeader: View {
    var stage: CharacterGrowthStage
    var streakDays: Int
    var isPremium: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            CharacterAvatarView(stage: stage, size: 96)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(stage.title)
                        .font(.headline)
                    Text(isPremium ? "PREMIUM" : "FREE")
                        .font(.caption2.bold())
                        .foregroundStyle(isPremium ? .yellow : .secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(.thinMaterial, in: Capsule())
                }

                Text(stage.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("継続 \(streakDays)日")
                    .font(.caption.bold())
                    .foregroundStyle(.blue)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 8)
    }
}

