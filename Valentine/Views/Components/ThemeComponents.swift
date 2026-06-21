import SwiftUI

enum ThemeStyle {
    case system, light, dark
}

struct ThemeSelectionView: View {
    @Binding var selection: Int
    
    var body: some View {
        HStack(spacing: 20) {
            ThemeThumbnail(title: "Follow System", isSelected: selection == 0, style: .system) {
                selection = 0
            }
            ThemeThumbnail(title: "Light", isSelected: selection == 1, style: .light) {
                selection = 1
            }
            ThemeThumbnail(title: "Dark", isSelected: selection == 2, style: .dark) {
                selection = 2
            }
        }
        .padding(.vertical, 8)
    }
}

struct ThemeThumbnail: View {
    let title: LocalizedStringKey
    let isSelected: Bool
    let style: ThemeStyle
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            Button(action: action) {
                ZStack {
                    // Background
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.clear)
                        .frame(width: 76, height: 52)
                    
                    if style == .system {
                        HStack(spacing: 0) {
                            ZStack {
                                LinearGradient(colors: [.cyan.opacity(0.6), .white], startPoint: .topLeading, endPoint: .bottomTrailing)
                                WindowGraphic(isDark: false)
                            }
                            ZStack {
                                LinearGradient(colors: [.blue.opacity(0.8), .black], startPoint: .topLeading, endPoint: .bottomTrailing)
                                WindowGraphic(isDark: true)
                            }
                        }
                        .frame(width: 72, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    } else {
                        let isDark = style == .dark
                        ZStack {
                            if isDark {
                                LinearGradient(colors: [.blue.opacity(0.8), .black], startPoint: .topLeading, endPoint: .bottomTrailing)
                            } else {
                                LinearGradient(colors: [.cyan.opacity(0.6), .white], startPoint: .topLeading, endPoint: .bottomTrailing)
                            }
                            WindowGraphic(isDark: isDark)
                        }
                        .frame(width: 72, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    
                    if isSelected {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.accentColor, lineWidth: 3)
                            .frame(width: 76, height: 52)
                    }
                }
            }
            .buttonStyle(.plain)
            
            Text(title)
                .font(.system(size: 11, weight: isSelected ? .bold : .regular))
        }
    }
}

struct WindowGraphic: View {
    let isDark: Bool
    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 12)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(isDark ? Color(white: 0.1) : .white)
                    .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                
                // Content bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.accentColor)
                    .frame(width: 40, height: 8)
                    .padding(.leading, 8)
                    .padding(.top, 8)
                
                // Traffic lights
                HStack(spacing: 2) {
                    Circle().fill(Color.red).frame(width: 4, height: 4)
                    Circle().fill(Color.yellow).frame(width: 4, height: 4)
                    Circle().fill(Color.green).frame(width: 4, height: 4)
                }
                .padding(.leading, 8)
                .padding(.top, 24)
            }
            .frame(width: 56, height: 40)
        }
    }
}

struct LiquidGlassSelectionView: View {
    @Binding var selection: Int
    
    var body: some View {
        HStack(spacing: 20) {
            LiquidGlassThumbnail(title: "Transparent", isSelected: selection == 1, isTinted: false) {
                selection = 1
            }
            LiquidGlassThumbnail(title: "Tinted", isSelected: selection == 0, isTinted: true) {
                selection = 0
            }
        }
        .padding(.vertical, 8)
    }
}

struct LiquidGlassThumbnail: View {
    let title: LocalizedStringKey
    let isSelected: Bool
    let isTinted: Bool
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 8) {
            Button(action: action) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.clear)
                        .frame(width: 86, height: 60)
                    
                    let isDark = colorScheme == .dark
                    
                    ZStack {
                        if isDark {
                            LinearGradient(colors: [.blue.opacity(0.8), .black], startPoint: .topLeading, endPoint: .bottomTrailing)
                        } else {
                            LinearGradient(colors: [.cyan.opacity(0.6), .white], startPoint: .topLeading, endPoint: .bottomTrailing)
                        }
                        
                        if isTinted {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(isDark ? Color.accentColor.opacity(0.4) : Color(white: 1.0).opacity(0.7))
                                .background(.regularMaterial)
                                .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                                .frame(width: 50, height: 26)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.clear)
                                .background(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(white: 1.0).opacity(isDark ? 0.2 : 0.6), lineWidth: 0.5)
                                )
                                .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                                .frame(width: 50, height: 26)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .frame(width: 80, height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    if isSelected {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.accentColor, lineWidth: 3)
                            .frame(width: 86, height: 60)
                    }
                }
            }
            .buttonStyle(.plain)
            
            Text(title)
                .font(.system(size: 11, weight: isSelected ? .bold : .regular))
        }
    }
}
