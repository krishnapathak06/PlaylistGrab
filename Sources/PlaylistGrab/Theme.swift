import SwiftUI

enum Theme {
    static let accentGradient = LinearGradient(
        colors: [Color(red: 0.96, green: 0.28, blue: 0.38), Color(red: 0.88, green: 0.16, blue: 0.48)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let accentBlueGradient = LinearGradient(
        colors: [Color(red: 0.20, green: 0.50, blue: 0.98), Color(red: 0.35, green: 0.30, blue: 0.95)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let primaryAccent = Color(red: 0.92, green: 0.22, blue: 0.38)
    static let cardBackground = Color(nsColor: .controlBackgroundColor)
    static let cardBorder = Color.primary.opacity(0.08)
    static let subtleHover = Color.primary.opacity(0.04)

    static let cornerRadius: CGFloat = 12
    static let cardCornerRadius: CGFloat = 10
}

struct CardModifier: ViewModifier {
    var padding: CGFloat = 14
    var cornerRadius: CGFloat = Theme.cardCornerRadius

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.75))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(Theme.cardBorder, lineWidth: 1)
            )
    }
}

struct SubtleButtonModifier: ViewModifier {
    var isActive: Bool = false

    func body(content: Content) -> some View {
        content
            .font(.subheadline)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isActive ? Theme.primaryAccent.opacity(0.15) : Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isActive ? Theme.primaryAccent.opacity(0.3) : Theme.cardBorder, lineWidth: 1)
            )
            .foregroundStyle(isActive ? Theme.primaryAccent : .primary)
    }
}

extension View {
    func asCard(padding: CGFloat = 14, cornerRadius: CGFloat = Theme.cardCornerRadius) -> some View {
        modifier(CardModifier(padding: padding, cornerRadius: cornerRadius))
    }

    func asPill(isActive: Bool = false) -> some View {
        modifier(SubtleButtonModifier(isActive: isActive))
    }
}
