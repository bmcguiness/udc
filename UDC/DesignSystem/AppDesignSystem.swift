import SwiftUI

enum AppSpacing { static let small: CGFloat = 8; static let medium: CGFloat = 16; static let large: CGFloat = 24 }
enum AppCornerRadius { static let small: CGFloat = 10; static let medium: CGFloat = 16; static let large: CGFloat = 24 }

extension Color {
    static let appAccent = Color.accentColor
    static let appSurface = Color(uiColor: .secondarySystemGroupedBackground)
}

struct AppCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(AppSpacing.medium).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.appSurface, in: RoundedRectangle(cornerRadius: AppCornerRadius.medium))
    }
}
