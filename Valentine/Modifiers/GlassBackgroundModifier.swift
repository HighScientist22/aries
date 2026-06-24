import SwiftUI

enum AriesGlassStyle {
    case regular
    case clear
    case interactive
}

enum LiquidGlassSettings {
    static let enabledKey = "liquidGlassEnabled"
}

struct AriesGlassEffectModifier<S: Shape>: ViewModifier {
    @AppStorage(LiquidGlassSettings.enabledKey) private var liquidGlassEnabled = true
    let style: AriesGlassStyle
    let shape: S

    func body(content: Content) -> some View {
        if liquidGlassEnabled {
            switch style {
            case .regular:
                content.glassEffect(.regular, in: shape)
            case .clear:
                content.glassEffect(.clear, in: shape)
            case .interactive:
                content.glassEffect(.regular.interactive(), in: shape)
            }
        } else {
            content
                .overlay(shape.stroke(Color.primary.opacity(0.08), lineWidth: 1))
        }
    }
}

struct AriesGlassShapelessModifier: ViewModifier {
    @AppStorage(LiquidGlassSettings.enabledKey) private var liquidGlassEnabled = true
    let style: AriesGlassStyle

    func body(content: Content) -> some View {
        if liquidGlassEnabled {
            switch style {
            case .regular:
                content.glassEffect(.regular)
            case .clear:
                content.glassEffect(.clear)
            case .interactive:
                content.glassEffect(.regular.interactive())
            }
        } else {
            content
                .background(.ultraThinMaterial.opacity(0.85), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )
        }
    }
}

extension View {
    func ariesGlass<S: Shape>(_ style: AriesGlassStyle = .regular, in shape: S) -> some View {
        modifier(AriesGlassEffectModifier(style: style, shape: shape))
    }

    func ariesGlass(_ style: AriesGlassStyle = .regular) -> some View {
        modifier(AriesGlassShapelessModifier(style: style))
    }

    func liquidGlass(cornerRadius: CGFloat = DesignConstants.CornerRadius.large) -> some View {
        modifier(LiquidGlassModifier(cornerRadius: cornerRadius))
    }
}

struct LiquidGlassModifier: ViewModifier {
    @AppStorage(LiquidGlassSettings.enabledKey) private var liquidGlassEnabled = true
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if liquidGlassEnabled {
            content
                .background(shape.glassEffect(.regular))
        } else {
            content
                .background(shape.fill(.ultraThinMaterial.opacity(0.85)))
                .overlay(shape.strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
        }
    }
}

struct LiquidGlassButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = DesignConstants.CornerRadius.large
    var isActive: Bool = false

    @AppStorage(LiquidGlassSettings.enabledKey) private var liquidGlassEnabled = true
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let highlighted = configuration.isPressed || isHovered || isActive

        configuration.label
            .background {
                if liquidGlassEnabled {
                    shape.glassEffect(highlighted ? .regular.interactive() : .regular)
                } else {
                    shape.fill(.ultraThinMaterial.opacity(highlighted ? 0.95 : 0.8))
                }
            }
            .overlay(
                shape
                    .fill(Color.white.opacity(isActive ? 0.25 : 0))
                    .blendMode(.overlay)
            )
            .overlay(
                shape
                    .stroke(
                        Color.white.opacity(isActive ? 0.5 : (isHovered ? 0.3 : 0.1)),
                        lineWidth: isActive ? 1.5 : 1
                    )
                    .blendMode(.overlay)
            )
            .scaleEffect(configuration.isPressed ? 0.92 : (isHovered ? 1.08 : 1.0))
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isHovered)
            .animation(.easeInOut(duration: 0.2), value: isActive)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}
