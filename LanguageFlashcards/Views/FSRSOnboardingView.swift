import SwiftUI

struct FSRSOnboardingView: View {
    var startAction: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("忘れそうなカードから出します")
                        .font(.largeTitle.bold())
                    Text("このアプリはFSRS-liteで、完璧・自信なし・不明の評価から次に出すカードを調整します。")
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 12) {
                    FSRSOnboardingRow(
                        icon: "checkmark.circle.fill",
                        title: "完璧",
                        detail: "記憶が強くなったと判断し、次の出題間隔を伸ばします。"
                    )
                    FSRSOnboardingRow(
                        icon: "questionmark.circle.fill",
                        title: "自信なし",
                        detail: "覚えかけのカードとして、近いタイミングで再表示します。"
                    )
                    FSRSOnboardingRow(
                        icon: "xmark.circle.fill",
                        title: "不明",
                        detail: "忘れているカードとして、かなり早く再表示します。"
                    )
                }

                Text("カードごとに難しさと記憶の安定度を見て、忘れそうなものほど出やすくします。")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    startAction()
                } label: {
                    Text("学習を始める")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("学習のしくみ")
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
