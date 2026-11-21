import SwiftUI
import AppKit

enum Theme {
    // Brand Gradients
    static let accentGradient = LinearGradient(
        colors: [Color(red: 1.0, green: 0.22, blue: 0.35), Color(red: 0.86, green: 0.12, blue: 0.44)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let accentBlueGradient = LinearGradient(
        colors: [Color(red: 0.18, green: 0.52, blue: 1.0), Color(red: 0.36, green: 0.32, blue: 0.98)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let emeraldGradient = LinearGradient(
        colors: [Color(red: 0.15, green: 0.78, blue: 0.52), Color(red: 0.10, green: 0.65, blue: 0.42)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let amberGradient = LinearGradient(
        colors: [Color(red: 0.98, green: 0.60, blue: 0.15), Color(red: 0.92, green: 0.42, blue: 0.10)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Solid Accents
    static let primaryAccent = Color(red: 0.95, green: 0.22, blue: 0.36)
    static let secondaryAccent = Color(red: 0.25, green: 0.50, blue: 1.0)
    static let successGreen = Color(red: 0.20, green: 0.78, blue: 0.45)
    static let warningAmber = Color(red: 0.96, green: 0.62, blue: 0.16)
    static let errorRed = Color(red: 0.95, green: 0.25, blue: 0.25)

    // Surfaces & Borders
    static let surfaceBackground = Color(nsColor: .windowBackgroundColor)
    static let cardBackground = Color(nsColor: .controlBackgroundColor).opacity(0.7)
    static let elevatedCardBackground = Color(nsColor: .textBackgroundColor).opacity(0.8)
    static let cardBorder = Color.primary.opacity(0.07)
    static let cardBorderHover = primaryAccent.opacity(0.25)
    static let subtleHover = Color.primary.opacity(0.04)

    static let cornerRadius: CGFloat = 12
    static let cardCornerRadius: CGFloat = 10
}

// MARK: - View Modifiers

struct GlassCardModifier: ViewModifier {
    var padding: CGFloat = 14
    var cornerRadius: CGFloat = Theme.cardCornerRadius
    var isHovered: Bool = false

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.75))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(isHovered ? Theme.primaryAccent.opacity(0.28) : Theme.cardBorder, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(isHovered ? 0.05 : 0.015), radius: isHovered ? 6 : 2, y: isHovered ? 3 : 1)
    }
}

struct PillBadgeModifier: ViewModifier {
    var color: Color = .blue
    var filled: Bool = false

    func body(content: Content) -> some View {
        content
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(filled ? color : color.opacity(0.12))
            )
            .overlay(
                Capsule()
                    .strokeBorder(filled ? Color.clear : color.opacity(0.25), lineWidth: 1)
            )
            .foregroundStyle(filled ? .white : color)
    }
}

extension View {
    func asCard(padding: CGFloat = 14, cornerRadius: CGFloat = Theme.cardCornerRadius, isHovered: Bool = false) -> some View {
        modifier(GlassCardModifier(padding: padding, cornerRadius: cornerRadius, isHovered: isHovered))
    }

    func asPillBadge(color: Color = .blue, filled: Bool = false) -> some View {
        modifier(PillBadgeModifier(color: color, filled: filled))
    }
}
