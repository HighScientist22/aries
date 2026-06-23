import SwiftUI

extension Notification.Name {
    static let openSettings = Notification.Name("AriesOpenSettings")
}

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case lyrics = "Lyrics"
    case integrations = "Integrations"
    case library = "Library"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .general: return "gear"
        case .lyrics: return "textformat.alt"
        case .integrations: return "network"
        case .library: return "folder"
        }
    }
    
    var color: Color {
        switch self {
        case .general: return .gray
        case .lyrics: return .blue
        case .integrations: return .red
        case .library: return .purple
        }
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedTab: SettingsTab? = .general
    @AppStorage("appTheme") private var appTheme = 0
    @EnvironmentObject var library: LibraryStore

    // Listen for requests to open settings to a specific tab. The opener
    // will write the desired tab to UserDefaults under "settingsOpenTab"
    // and post `.openSettings` so the app can bring the window forward.
    private var settingsOpenPublisher: NotificationCenter.Publisher {
        NotificationCenter.default.publisher(for: .openSettings)
    }
    
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
            case .library:
                LibrarySettingsView()
                    .navigationTitle(LocalizedStringKey(SettingsTab.library.rawValue))
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
        .onReceive(settingsOpenPublisher) { notification in
            if let tabName = notification.userInfo?["tab"] as? String, let tab = SettingsTab(rawValue: tabName) {
                selectedTab = tab
            } else if let raw = UserDefaults.standard.string(forKey: "settingsOpenTab"), let tab = SettingsTab(rawValue: raw) {
                selectedTab = tab
                UserDefaults.standard.removeObject(forKey: "settingsOpenTab")
            } else {
                selectedTab = .general
            }
        }
        .onAppear {
            if let raw = UserDefaults.standard.string(forKey: "settingsOpenTab"), let tab = SettingsTab(rawValue: raw.capitalized) {
                selectedTab = tab
                UserDefaults.standard.removeObject(forKey: "settingsOpenTab")
            }
        }
    }
}


