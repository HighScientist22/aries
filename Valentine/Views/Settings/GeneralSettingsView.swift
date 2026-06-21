import SwiftUI

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
