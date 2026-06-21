import SwiftUI

struct HoverButton: View {
    let title: LocalizedStringKey
    let isPrimary: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundColor(isPrimary ? .white : .primary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(isPrimary ? Color.accentColor.opacity(0.6) : Color.secondary.opacity(0.2))
                .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .scaleEffect(isHovered ? 1.02 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)
                .onHover { hovering in
                    isHovered = hovering
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
        }
        .buttonStyle(.plain)
    }
}
