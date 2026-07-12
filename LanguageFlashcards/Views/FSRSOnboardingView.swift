import SwiftUI

struct FSRSOnboardingView: View {
    var startAction: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("fsrsOnboarding.hero.title")
                        .font(.largeTitle.bold())
                    Text("fsrsOnboarding.hero.description")
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 12) {
                    FSRSOnboardingRow(
                        icon: "checkmark.circle.fill",
                        title: String(localized: "reviewRating.title.perfect"),
                        detail: String(localized: "fsrsOnboarding.perfect.detail")
                    )
                    FSRSOnboardingRow(
                        icon: "questionmark.circle.fill",
                        title: String(localized: "reviewRating.title.unsure"),
                        detail: String(localized: "fsrsOnboarding.unsure.detail")
                    )
                    FSRSOnboardingRow(
                        icon: "xmark.circle.fill",
                        title: String(localized: "reviewRating.title.unknown"),
                        detail: String(localized: "fsrsOnboarding.unknown.detail")
                    )
                }

                Text("fsrsOnboarding.footer")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    startAction()
                } label: {
                    Text("fsrsOnboarding.start")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle(String(localized: "fsrsOnboarding.navigationTitle"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct FSRSOnboardingRow: View {
    var icon: String
    var title: String
    var detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
