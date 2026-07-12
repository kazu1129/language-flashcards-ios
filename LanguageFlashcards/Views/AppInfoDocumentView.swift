import SwiftUI

enum AppInfoDocument {
    case manual
    case privacyPolicy
    case termsOfUse

    var title: String {
        switch self {
        case .manual:
            String(localized: "appInfo.manual.title")
        case .privacyPolicy:
            String(localized: "appInfo.privacy.title")
        case .termsOfUse:
            String(localized: "appInfo.terms.title")
        }
    }

    var sections: [AppInfoSection] {
        switch self {
        case .manual:
            [
                AppInfoSection(
                    heading: String(localized: "appInfo.manual.account.heading"),
                    body: String(localized: "appInfo.manual.account.body")
                ),
                AppInfoSection(
                    heading: String(localized: "appInfo.manual.basic.heading"),
                    body: String(localized: "appInfo.manual.basic.body")
                ),
                AppInfoSection(
                    heading: String(localized: "appInfo.manual.addCards.heading"),
                    body: String(localized: "appInfo.manual.addCards.body")
                ),
                AppInfoSection(
                    heading: String(localized: "appInfo.manual.import.heading"),
                    body: String(localized: "appInfo.manual.import.body")
                ),
                AppInfoSection(
                    heading: String(localized: "appInfo.manual.editShare.heading"),
                    body: String(localized: "appInfo.manual.editShare.body")
                ),
                AppInfoSection(
                    heading: String(localized: "appInfo.manual.premium.heading"),
                    body: String(localized: "appInfo.manual.premium.body")
                ),
                AppInfoSection(
                    heading: String(localized: "appInfo.manual.progress.heading"),
                    body: String(localized: "appInfo.manual.progress.body")
                ),
                AppInfoSection(
                    heading: String(localized: "appInfo.manual.notifications.heading"),
                    body: String(localized: "appInfo.manual.notifications.body")
                ),
                AppInfoSection(
                    heading: String(localized: "appInfo.manual.fsrs.heading"),
                    body: String(localized: "appInfo.manual.fsrs.body")
                )
            ]
        case .privacyPolicy:
            [
                AppInfoSection(
                    heading: String(localized: "appInfo.privacy.data.heading"),
                    body: String(localized: "appInfo.privacy.data.body")
                ),
                AppInfoSection(
                    heading: String(localized: "appInfo.privacy.purpose.heading"),
                    body: String(localized: "appInfo.privacy.purpose.body")
                ),
                AppInfoSection(
                    heading: String(localized: "appInfo.privacy.thirdParty.heading"),
                    body: String(localized: "appInfo.privacy.thirdParty.body")
                ),
                AppInfoSection(
                    heading: String(localized: "appInfo.privacy.ocr.heading"),
                    body: String(localized: "appInfo.privacy.ocr.body")
                ),
                AppInfoSection(
                    heading: String(localized: "appInfo.privacy.subscriptionLink.heading"),
                    body: String(localized: "appInfo.privacy.subscriptionLink.body")
                ),
                AppInfoSection(
                    heading: String(localized: "appInfo.privacy.shareSave.heading"),
                    body: String(localized: "appInfo.privacy.shareSave.body")
                ),
                AppInfoSection(
                    heading: String(localized: "appInfo.privacy.retention.heading"),
                    body: String(localized: "appInfo.privacy.retention.body")
                ),
                AppInfoSection(
                    heading: String(localized: "appInfo.privacy.permissions.heading"),
                    body: String(localized: "appInfo.privacy.permissions.body")
                ),
                AppInfoSection(
                    heading: String(localized: "appInfo.privacy.contact.heading"),
                    body: String(localized: "appInfo.privacy.contact.body")
                )
            ]
        case .termsOfUse:
            [
                AppInfoSection(
                    heading: String(localized: "appInfo.terms.conditions.heading"),
                    body: String(localized: "appInfo.terms.conditions.body")
                ),
                AppInfoSection(
                    heading: String(localized: "appInfo.terms.userContent.heading"),
                    body: String(localized: "appInfo.terms.userContent.body")
                ),
                AppInfoSection(
                    heading: String(localized: "appInfo.terms.premiumTrial.heading"),
                    body: String(localized: "appInfo.terms.premiumTrial.body")
                ),
                AppInfoSection(
                    heading: String(localized: "appInfo.terms.cancel.heading"),
                    body: String(localized: "appInfo.terms.cancel.body")
                ),
                AppInfoSection(
                    heading: String(localized: "appInfo.terms.disclaimer.heading"),
                    body: String(localized: "appInfo.terms.disclaimer.body")
                ),
                AppInfoSection(
                    heading: String(localized: "appInfo.terms.eula.heading"),
                    body: String(localized: "appInfo.terms.eula.body")
                ),
                AppInfoSection(
                    heading: String(localized: "appInfo.terms.changes.heading"),
                    body: String(localized: "appInfo.terms.changes.body")
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
