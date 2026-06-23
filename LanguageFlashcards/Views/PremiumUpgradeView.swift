import SwiftUI

struct PremiumUpgradeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("1週間無料プレミアムトライアル")
                            .font(.title.bold())
                        Text("まずは7日間、カード数・OCR・分析・共有を広げて試せます。無料でも学習は続けられます。")
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 12) {
                        PremiumBenefitRow(icon: "rectangle.stack.badge.plus", title: "カードとセットを無制限に", detail: "無料は3セット・100カードまで。")
                        PremiumBenefitRow(icon: "camera.viewfinder", title: "写真OCRをもっと使える", detail: "無料は月10回まで。メモ写真からまとめて追加。")
                        PremiumBenefitRow(icon: "chart.line.uptrend.xyaxis", title: "詳しい成果分析", detail: "長期推移や弱点の把握をしやすく。")
                        PremiumBenefitRow(icon: "square.and.arrow.up", title: "PDF共有に対応", detail: "学習セットをきれいに出力。")
                        PremiumBenefitRow(icon: "leaf.fill", title: "継続を後押しする通知", detail: "成長通知や記念日メッセージで続けやすく。")
                    }

                    Button {
                        settings.subscriptionTier = .premium
                        dismiss()
                    } label: {
                        Text("1週間無料プレミアムトライアルを開始")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Text("現在は開発用の切替です。App Store公開時はAppleの1週間無料トライアル付きサブスクリプション購入状態と連携します。")
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
                    Label("1週間無料プレミアムトライアル", systemImage: "crown.fill")
                        .font(.headline)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                }

                Text("無制限カード、OCR、PDF共有、詳しい成果分析を7日間試せます。")
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
