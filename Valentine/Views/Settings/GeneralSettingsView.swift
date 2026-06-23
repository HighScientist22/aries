import SwiftUI
import Combine
import AppKit

struct SelectableTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String = ""
    var focused: Bool = false
    
    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.placeholderString = placeholder
        textField.delegate = context.coordinator
        return textField
    }
    
    func updateNSView(_ nsView: NSTextField, context: Context) {
        nsView.stringValue = text
        // Only focus/select on transition from unfocused to focused (one-time action)
        if focused && !context.coordinator.wasFocused {
            DispatchQueue.main.async {
                nsView.selectText(nil)
                nsView.window?.makeFirstResponder(nsView)
            }
            context.coordinator.wasFocused = true
        } else if !focused {
            context.coordinator.wasFocused = false
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        @Binding var text: String
        var wasFocused: Bool = false
        
        init(text: Binding<String>) {
            self._text = text
        }
        
        func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                text = textField.stringValue
            }
        }
    }
}


struct GeneralSettingsView: View {
    @AppStorage("isGlowEffectEnabled") private var isGlowEffectEnabled = false
    @AppStorage("isNeonEffectEnabled") private var isNeonEffectEnabled = false
    @AppStorage("miniPlayerGlassMode") private var miniPlayerGlassMode = 0
    @AppStorage("appTheme") private var appTheme = 0
    @AppStorage("customGreeting") private var customGreeting: String = ""
    @State private var selectGreetingText: Bool = false

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
            VStack(alignment: .leading, spacing: 12) {
                Text("Custom Greeting")
                    .font(.headline)
                SelectableTextField(text: $customGreeting, placeholder: "Welcome back, user!", focused: selectGreetingText)
                    .padding(.top, 4)
                Text("A short greeting shown in the UI where appropriate.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 6)

            Section(header: Text("Equalizer")) {
                NavigationLink(destination: EqualizerSettingsView()) {
                    Text("Open Equalizer Settings")
                }
            }

            Section(header: Text("Synced Lyrics Effects")) {
                Toggle("Glow Effect", isOn: $isGlowEffectEnabled)
                Toggle("Neon Effect", isOn: $isNeonEffectEnabled)
            }
        }
        .formStyle(.grouped)
        .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { notification in
            if let tab = notification.userInfo?["tab"] as? String, tab == SettingsTab.general.rawValue {
                selectGreetingText = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    selectGreetingText = false
                }
            }
        }
        .onAppear {
            if let raw = UserDefaults.standard.string(forKey: "settingsOpenTab"), raw == SettingsTab.general.rawValue {
                selectGreetingText = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    selectGreetingText = false
                }
                UserDefaults.standard.removeObject(forKey: "settingsOpenTab")
            }
        }
    }
}
