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
                    Text(stage.localizedTitle)
                        .font(.headline)
                    Text(isPremium ? "PREMIUM" : "FREE")
                        .font(.caption2.bold())
                        .foregroundStyle(isPremium ? .yellow : .secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(.thinMaterial, in: Capsule())
                }

                Text(stage.localizedSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(String.localizedStringWithFormat(
                    String(localized: "character.streak"),
                    Int64(streakDays)
                ))
                    .font(.caption.bold())
                    .foregroundStyle(.blue)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 8)
    }
}

enum CharacterCelebrationMotion: CaseIterable, Equatable {
    case bounce
    case wiggle
    case pop
    case float

    static func random(excluding previousMotion: CharacterCelebrationMotion? = nil) -> CharacterCelebrationMotion {
        let candidates = allCases.filter { $0 != previousMotion }
        return candidates.randomElement() ?? .bounce
    }
}

struct CharacterCelebrationView: View {
    var stage: CharacterGrowthStage
    var size: CGFloat = 118
    var motion: CharacterCelebrationMotion = .bounce

    @State private var isCelebrating = false

    var body: some View {
        ZStack {
            animatedCharacter

            Image(systemName: "sparkles")
                .font(.system(size: size * 0.18, weight: .bold))
                .foregroundStyle(.yellow)
                .offset(x: size * 0.36, y: isCelebrating ? -size * 0.44 : -size * 0.34)
                .scaleEffect(isCelebrating ? 1.14 : 0.82)
                .opacity(isCelebrating ? 1 : 0.55)

            Circle()
                .fill(.cyan.opacity(0.72))
                .frame(width: size * 0.1, height: size * 0.1)
                .offset(x: -size * 0.43, y: isCelebrating ? -size * 0.18 : -size * 0.3)
                .opacity(isCelebrating ? 0.8 : 0.35)
        }
        .frame(width: size * 1.32, height: size * 1.28)
        .onAppear {
            withAnimation(animation.repeatForever(autoreverses: true)) {
                isCelebrating = true
            }
        }
    }

    private var animatedCharacter: some View {
        ZStack {
            Image(stage.imageName)
                .resizable()
                .scaledToFill()
                .frame(width: size * 1.16, height: size * 1.16)
                .scaleEffect(characterScale)
                .rotationEffect(.degrees(characterRotation))
                .offset(characterOffset)

            animatedHands
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.7), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
    }

    private var animatedHands: some View {
        ZStack {
            celebrationHand(isLeft: true)
                .rotationEffect(.degrees(handRotation(isLeft: true)), anchor: .bottom)
                .offset(handOffset(isLeft: true))
                .scaleEffect(handScale(isLeft: true))

            celebrationHand(isLeft: false)
                .rotationEffect(.degrees(handRotation(isLeft: false)), anchor: .bottom)
                .offset(handOffset(isLeft: false))
                .scaleEffect(handScale(isLeft: false))
        }
        .accessibilityHidden(true)
    }

    private func celebrationHand(isLeft: Bool) -> some View {
        ZStack(alignment: .top) {
            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.blue.opacity(0.95), .cyan.opacity(0.82)],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .frame(width: size * 0.11, height: size * 0.34)

            Circle()
                .fill(.cyan.opacity(0.94))
                .frame(width: size * 0.17, height: size * 0.17)
                .overlay(
                    Circle()
                        .stroke(.white.opacity(0.82), lineWidth: 1)
                )
                .offset(y: -size * 0.06)
        }
        .shadow(color: .blue.opacity(0.22), radius: 4, x: 0, y: 3)
        .offset(x: isLeft ? -size * 0.2 : size * 0.2, y: size * 0.18)
    }

    private var animation: Animation {
        switch motion {
        case .bounce:
            .easeInOut(duration: 0.48)
        case .wiggle:
            .easeInOut(duration: 0.34)
        case .pop:
            .easeInOut(duration: 0.42)
        case .float:
            .easeInOut(duration: 0.78)
        }
    }

    private var characterScale: CGFloat {
        switch motion {
        case .bounce:
            isCelebrating ? 1.05 : 0.97
        case .wiggle:
            isCelebrating ? 1.03 : 1
        case .pop:
            isCelebrating ? 1.1 : 0.94
        case .float:
            isCelebrating ? 1.04 : 0.99
        }
    }

    private var characterRotation: Double {
        switch motion {
        case .bounce:
            isCelebrating ? 1.5 : -1.5
        case .wiggle:
            isCelebrating ? 5 : -5
        case .pop:
            isCelebrating ? -2.5 : 2.5
        case .float:
            isCelebrating ? 2.5 : -1
        }
    }

    private var characterOffset: CGSize {
        switch motion {
        case .bounce:
            CGSize(width: 0, height: isCelebrating ? -size * 0.07 : size * 0.05)
        case .wiggle:
            CGSize(width: isCelebrating ? size * 0.045 : -size * 0.045, height: -size * 0.01)
        case .pop:
            CGSize(width: 0, height: isCelebrating ? -size * 0.03 : size * 0.03)
        case .float:
            CGSize(width: isCelebrating ? size * 0.03 : -size * 0.02, height: isCelebrating ? -size * 0.09 : size * 0.04)
        }
    }

    private func handRotation(isLeft: Bool) -> Double {
        let direction = isLeft ? -1.0 : 1.0
        switch motion {
        case .bounce:
            return direction * (isCelebrating ? 31 : 12)
        case .wiggle:
            return direction * (isCelebrating ? 44 : 18)
        case .pop:
            return direction * (isCelebrating ? 12 : 34)
        case .float:
            return direction * (isCelebrating ? 28 : 8)
        }
    }

    private func handOffset(isLeft: Bool) -> CGSize {
        let direction = isLeft ? -1.0 : 1.0
        switch motion {
        case .bounce:
            return CGSize(width: direction * size * 0.05, height: isCelebrating ? -size * 0.23 : -size * 0.05)
        case .wiggle:
            return CGSize(width: direction * (isCelebrating ? size * 0.1 : size * 0.02), height: -size * 0.16)
        case .pop:
            return CGSize(width: direction * (isCelebrating ? size * 0.04 : size * 0.18), height: isCelebrating ? -size * 0.2 : -size * 0.08)
        case .float:
            return CGSize(width: direction * (isCelebrating ? size * 0.08 : size * 0.03), height: isCelebrating ? -size * 0.24 : -size * 0.12)
        }
    }

    private func handScale(isLeft: Bool) -> CGFloat {
        switch motion {
        case .bounce:
            return isCelebrating ? 1.08 : 0.96
        case .wiggle:
            return isLeft == isCelebrating ? 1.1 : 0.98
        case .pop:
            return isCelebrating ? 1.04 : 0.92
        case .float:
            return isCelebrating ? 1.03 : 0.97
        }
    }
}
