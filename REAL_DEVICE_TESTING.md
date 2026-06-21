# 実機確認チェックリスト

このプロジェクトは実機確認用に Automatic Signing を有効化し、Team `UYAG3JDD7G` を設定しています。

## 1. XcodeにApple IDを追加

1. Xcodeを開く
2. `Xcode` > `Settings...` > `Accounts`
3. `+` からApple IDを追加
4. Teamに `UYAG3JDD7G` が表示されることを確認

現在の署名エラー:

```text
No Account for Team "UYAG3JDD7G"
No profiles for 'com.kazu1129.LanguageFlashcards' were found
```

これはコードの問題ではなく、XcodeにApple IDが登録されていない、またはプロビジョニングプロファイルがまだ作られていない状態です。

## 2. iPhoneをオンラインにする

1. iPhoneをMacに接続
2. iPhoneをロック解除
3. `このコンピュータを信頼しますか？` が出たら `信頼`
4. iPhoneの `設定` > `プライバシーとセキュリティ` > `デベロッパモード` をオン
5. 必要ならiPhoneを再起動

現在、Xcodeからは `kazu1129` というiPhoneが見えていますが、Offline状態です。

## 3. Xcodeから実行

1. `LanguageFlashcards.xcodeproj` を開く
2. 左上の実行先で iPhone `kazu1129` を選択
3. `LanguageFlashcards` ターゲットを選択
4. `Signing & Capabilities` で以下を確認
   - Automatically manage signing: ON
   - Team: `UYAG3JDD7G`
   - Bundle Identifier: `com.kazu1129.LanguageFlashcards`
5. Runボタンを押す

## 4. よくある原因

- iPhoneがロック中、またはMacを信頼していない
- iPhoneのDeveloper Modeがオフ
- XcodeにApple IDが追加されていない
- Apple IDの認証期限が切れている
- Bundle Identifierのプロビジョニングプロファイルがまだ作成されていない

