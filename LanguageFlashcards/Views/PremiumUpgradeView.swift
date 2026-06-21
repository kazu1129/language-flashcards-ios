import SwiftUI

struct PremiumUpgradeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("プレミアムで、学習を続けやすく")
                            .font(.title.bold())
                        Text("無料でも学習はできます。プレミアムでは、カード数・AI補完・OCR・分析・共有を広げられます。")
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 12) {
                        PremiumBenefitRow(icon: "rectangle.stack.badge.plus", title: "カードとセットを無制限に", detail: "無料は3セット・100カードまで。")
                        PremiumBenefitRow(icon: "sparkles", title: "Gemini補完をもっと使える", detail: "無料は1日5回まで。意味と例文作成を強化。")
                        PremiumBenefitRow(icon: "camera.viewfinder", title: "写真OCRをもっと使える", detail: "無料は月10回まで。メモ写真からまとめて追加。")
                        PremiumBenefitRow(icon: "chart.line.uptrend.xyaxis", title: "詳しい成果分析", detail: "長期推移や弱点の把握をしやすく。")
                        PremiumBenefitRow(icon: "square.and.arrow.up", title: "PDF共有に対応", detail: "学習セットをきれいに出力。")
                        PremiumBenefitRow(icon: "leaf.fill", title: "継続を後押しする通知", detail: "成長通知や記念日メッセージで続けやすく。")
                    }

                    Button {
                        settings.subscriptionTier = .premium
                        dismiss()
                    } label: {
                        Text("プレミアムに切り替える")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Text("現在は開発用の切替です。App Store公開時はAppleのサブスクリプション購入状態と連携します。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("プレミアム")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}

struct PremiumHomeCard: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("プレミアムで学習を広げる", systemImage: "crown.fill")
                        .font(.headline)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                }

                Text("無制限カード、Gemini補完、OCR、PDF共有、詳しい成果分析が使えます。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct PremiumBenefitRow: View {
    var icon: String
    var title: String
    var detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
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

