import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedTab: SettingsTab? = .general
    @AppStorage("appTheme") private var appTheme = 0
    @EnvironmentObject var library: LibraryStore
    @EnvironmentObject var navigation: AppNavigation

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
        .onChange(of: navigation.requestedSettingsTab) { _, tab in
            if let tab { selectedTab = tab }
        }
        .onAppear {
            if let tab = navigation.requestedSettingsTab {
                selectedTab = tab
            }
        }
    }
}
