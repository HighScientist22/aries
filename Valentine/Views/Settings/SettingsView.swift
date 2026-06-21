import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case lyrics = "Lyrics"
    case integrations = "Integrations"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .general: return "gear"
        case .lyrics: return "textformat.alt"
        case .integrations: return "network"
        }
    }
    
    var color: Color {
        switch self {
        case .general: return .gray
        case .lyrics: return .blue
        case .integrations: return .red
        }
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedTab: SettingsTab? = .general
    @AppStorage("appTheme") private var appTheme = 0
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                ForEach(SettingsTab.allCases) { tab in
                    NavigationLink(value: tab) {
                        Label {
                            Text(LocalizedStringKey(tab.rawValue))
                        } icon: {
                            Image(systemName: tab.icon)
                                .foregroundColor(.white)
                                .frame(width: 20, height: 20)
                                .background(tab.color, in: RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .listStyle(.sidebar)
        } detail: {
            switch selectedTab {
            case .general:
                GeneralSettingsView()
                    .navigationTitle(LocalizedStringKey(SettingsTab.general.rawValue))
            case .lyrics:
                LyricsAppearanceView()
                    .navigationTitle(LocalizedStringKey(SettingsTab.lyrics.rawValue))
            case .integrations:
                IntegrationsSettingsView()
                    .navigationTitle(LocalizedStringKey(SettingsTab.integrations.rawValue))
            case .none:
                Text("Select a setting")
            }
        }
        .frame(minWidth: 600, idealWidth: 700, minHeight: 400, idealHeight: 500)
        .background(WindowButtonsHider())
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                }
                .help("Close Settings")
            }
        }
    }
}

struct GeneralSettingsView: View {
    @AppStorage("isGlowEffectEnabled") private var isGlowEffectEnabled = false
    @AppStorage("isNeonEffectEnabled") private var isNeonEffectEnabled = false
    @AppStorage("miniPlayerGlassMode") private var miniPlayerGlassMode = 0
    @AppStorage("appTheme") private var appTheme = 0

    var body: some View {
        Form {
            Section(header: Text("Appearance")) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("App Theme")
                    ThemeSelectionView(selection: $appTheme)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mini Player Appearance")
                        .font(.body)
                    Text("Choose an appearance for the mini player.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    LiquidGlassSelectionView(selection: $miniPlayerGlassMode)
                        .padding(.top, 4)
                }
                .padding(.vertical, 8)
            }
            
            Section(header: Text("Synced Lyrics Effects")) {
                Toggle("Glow Effect", isOn: $isGlowEffectEnabled)
                Toggle("Neon Effect", isOn: $isNeonEffectEnabled)
            }
        }
        .formStyle(.grouped)
    }
}

struct LyricsAppearanceView: View {
    @ObservedObject var settings = LyricsAppearanceManager.shared
    
    @State private var previewIsDark = true
    @State private var previewNeon = false
    @State private var previewGlow = false
    @State private var applyMode = 0 // 0: Both Themes, 1: Specific Theme
    
    // Bindings for the currently selected theme to edit
    private var isEditingDark: Bool {
        if applyMode == 0 { return previewIsDark }
        return previewIsDark // Wait, if specific theme, it edits the preview's current theme.
    }
    
    private var fontDesignBinding: Binding<Int> {
        Binding(
            get: { isEditingDark ? settings.fontDesignDark : settings.fontDesignLight },
            set: { newValue in
                if applyMode == 0 {
                    settings.fontDesignDark = newValue
                    settings.fontDesignLight = newValue
                } else {
                    if isEditingDark { settings.fontDesignDark = newValue }
                    else { settings.fontDesignLight = newValue }
                }
            }
        )
    }
    
    private func colorBinding(for stringBindingLight: Binding<String>, stringBindingDark: Binding<String>, defaultColor: Color) -> Binding<Color> {
        Binding<Color>(
            get: {
                let hex = isEditingDark ? stringBindingDark.wrappedValue : stringBindingLight.wrappedValue
                return hex.isEmpty ? defaultColor : Color(hex: hex)
            },
            set: { newValue in
                let hex = newValue.toHex()
                if applyMode == 0 {
                    stringBindingDark.wrappedValue = hex
                    stringBindingLight.wrappedValue = hex
                } else {
                    if isEditingDark { stringBindingDark.wrappedValue = hex }
                    else { stringBindingLight.wrappedValue = hex }
                }
            }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // PREVIEW SECTION
            VStack {
                HStack {
                    Text("Preview")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Toggle("Dark Mode", isOn: $previewIsDark)
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                }
                .padding()
                
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(previewIsDark ? Color(white: 0.1) : Color(white: 0.95))
                    
                    VStack(spacing: 16) {
                        previewText("Lorem ipsum dolor sit amet", isActive: false)
                        previewText("Consectetur adipiscing elit", isActive: true)
                        previewText("Sed do eiusmod tempor", isActive: false)
                    }
                }
                .frame(height: 180)
                .padding(.horizontal)
                .padding(.bottom)
            }
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // SETTINGS SECTION
            ScrollView {
                VStack(spacing: 24) {
                    Picker("Apply to:", selection: $applyMode) {
                        Text("Both Themes").tag(0)
                        Text(previewIsDark ? "Dark Theme Only" : "Light Theme Only").tag(1)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    HStack {
                        Toggle("Neon Effect", isOn: $previewNeon)
                        Spacer()
                        Toggle("Glow Effect", isOn: $previewGlow)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Typography")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        Picker("Font Design", selection: fontDesignBinding) {
                            Text("Rounded").tag(1)
                            Text("Default").tag(0)
                            Text("Monospaced").tag(2)
                            Text("Serif").tag(3)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Colors")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        ColorPicker("Font Color", selection: colorBinding(for: $settings.fontColorLight, stringBindingDark: $settings.fontColorDark, defaultColor: .primary))
                        ColorPicker("Neon Color", selection: colorBinding(for: $settings.neonColorLight, stringBindingDark: $settings.neonColorDark, defaultColor: .white))
                        ColorPicker("Glow Color", selection: colorBinding(for: $settings.glowColorLight, stringBindingDark: $settings.glowColorDark, defaultColor: .accentColor))
                    }
                    
                    Button("Reset to Defaults") {
                        settings.resetToDefaults()
                    }
                    .padding(.top, 10)
                }
                .padding(24)
            }
        }
    }
    
    private func previewText(_ text: String, isActive: Bool) -> some View {
        Text(text)
            .font(.system(size: isActive ? 24 : 18, weight: isActive ? .bold : .medium, design: settings.getFontDesign(isDark: previewIsDark)))
            .foregroundColor((previewNeon && isActive) ? settings.getNeonColor(isDark: previewIsDark) : settings.getFontColor(isDark: previewIsDark, isActive: isActive))
            .shadow(color: (previewNeon && isActive) ? settings.getNeonColor(isDark: previewIsDark).opacity(0.8) : .clear, radius: 10, x: 0, y: 0)
            .shadow(color: (previewNeon && isActive) ? settings.getNeonColor(isDark: previewIsDark).opacity(0.4) : .clear, radius: 20, x: 0, y: 0)
            .shadow(color: (previewGlow && isActive) ? settings.getGlowColor(isDark: previewIsDark).opacity(0.8) : .clear, radius: 15, x: 0, y: 0)
            .shadow(color: (previewGlow && isActive) ? settings.getGlowColor(isDark: previewIsDark).opacity(0.5) : .clear, radius: 5, x: 0, y: 0)
    }
}

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

struct WindowButtonsHider: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.standardWindowButton(.closeButton)?.isHidden = true
                window.standardWindowButton(.miniaturizeButton)?.isHidden = true
                window.standardWindowButton(.zoomButton)?.isHidden = true
            }
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
