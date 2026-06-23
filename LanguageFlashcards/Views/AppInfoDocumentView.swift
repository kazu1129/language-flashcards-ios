import SwiftUI

enum AppInfoDocument {
    case manual
    case privacyPolicy
    case termsOfUse

    var title: String {
        switch self {
        case .manual:
            "取説"
        case .privacyPolicy:
            "プライバシーポリシー"
        case .termsOfUse:
            "利用規約"
        }
    }

    var sections: [AppInfoSection] {
        switch self {
        case .manual:
            [
                AppInfoSection(
                    heading: "基本の使い方",
                    body: "ホームでフラッシュカードセットを選び、「学習を開始」からセッションを始めます。カードは左右スワイプで移動し、タップすると裏面が表示されます。裏面では発音、意味、例文を確認できます。"
                ),
                AppInfoSection(
                    heading: "カードの追加",
                    body: "セット画面右上の追加ボタンから、直接入力、写真撮影、写真選択、CSV/TXT読み込みを選べます。CSV/TXTでは英語と日本語の順序が逆でも、アプリが英語側と日本語側を自動判定します。"
                ),
                AppInfoSection(
                    heading: "編集と共有",
                    body: "カードをタップすると編集できます。カード一覧では検索、スワイプ削除、長押しメニューからの編集/削除が使えます。共有ボタンからTXT、CSV、PDFでセットを書き出せます。"
                ),
                AppInfoSection(
                    heading: "学習結果",
                    body: "各カードの記憶度を「完璧」「まだ自信ない」「わからなかった」で記録します。成果タブでは今日の学習数、カレンダー、推移グラフを確認できます。"
                )
            ]
        case .privacyPolicy:
            [
                AppInfoSection(
                    heading: "収集するデータ",
                    body: "このアプリは、ユーザーが入力したフラッシュカード、学習履歴、設定、通知設定、Gemini APIキーを端末内に保存します。Gemini APIキーはKeychainに保存されます。アプリ独自のアカウント登録はありません。"
                ),
                AppInfoSection(
                    heading: "データの利用目的",
                    body: "保存データは、フラッシュカード学習、忘却曲線にもとづく出題、成果表示、通知、カードの共有ファイル作成のために利用します。"
                ),
                AppInfoSection(
                    heading: "第三者サービス",
                    body: "Gemini補完を使う場合、入力した単語やフレーズがGoogle Gemini APIへ送信され、意味や例文の作成に利用されます。Geminiを使わない場合、カード内容は外部AIへ送信されません。写真OCRは端末のVision機能で処理します。"
                ),
                AppInfoSection(
                    heading: "共有と保存",
                    body: "カードデータは原則として端末内に保存されます。ユーザーがTXT、CSV、PDF共有を実行した場合のみ、選択した共有先へデータが渡されます。"
                ),
                AppInfoSection(
                    heading: "保持と削除",
                    body: "カード、学習履歴、設定はユーザーがアプリ内で削除するか、アプリを削除するまで端末に保持されます。カードやセットはアプリ内で削除できます。端末からアプリを削除すると、ローカルデータも削除されます。"
                ),
                AppInfoSection(
                    heading: "権限",
                    body: "写真やカメラへのアクセスは、メモ写真から単語やフレーズを抽出する目的でのみ使用します。通知は学習リマインド、成果通知、記念日通知に使用します。"
                )
            ]
        case .termsOfUse:
            [
                AppInfoSection(
                    heading: "利用条件",
                    body: "このアプリは語学学習を支援するためのフラッシュカードアプリです。ユーザーは、自分が利用権限を持つ単語リスト、メモ、例文を登録してください。"
                ),
                AppInfoSection(
                    heading: "プレミアムと無料トライアル",
                    body: "プレミアムではカード数、AI補完、OCR、共有、分析機能の制限が広がります。App Store公開時は、1週間無料プレミアムトライアル付きの自動更新サブスクリプションとして提供する想定です。無料期間終了後の価格、期間、更新条件は購入画面に表示される内容に従います。"
                ),
                AppInfoSection(
                    heading: "解約",
                    body: "App Store経由のサブスクリプションは、ユーザーのApple IDのサブスクリプション管理画面からいつでも解約できます。無料トライアル期間中に解約した場合、次回以降の請求は発生しません。"
                ),
                AppInfoSection(
                    heading: "生成内容について",
                    body: "AI補完や検索にもとづく意味・例文は学習補助を目的としています。正確性を保証するものではないため、必要に応じて辞書や信頼できる資料で確認してください。"
                ),
                AppInfoSection(
                    heading: "免責",
                    body: "このアプリは可能な限り安定して動作するよう設計されていますが、学習成果、生成内容、共有ファイルの利用結果について特定の結果を保証しません。"
                ),
                AppInfoSection(
                    heading: "標準EULA",
                    body: "App Storeから配布されるアプリとして、Appleの標準エンドユーザー使用許諾契約、またはApp Store Connectで設定するカスタム利用規約が適用されます。"
                )
            ]
        }
    }
}

struct AppInfoSection: Identifiable {
    let id = UUID()
    var heading: String
    var body: String
}

struct AppInfoDocumentView: View {
    let document: AppInfoDocument

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ForEach(document.sections) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.heading)
                            .font(.headline)
                        Text(section.body)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
        }
        .navigationTitle(document.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
