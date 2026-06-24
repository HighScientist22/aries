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
    @AppStorage("gaplessPlayback") private var gaplessPlayback = true
    @AppStorage("crossfadeDuration") private var crossfadeDuration = 0.0
    @AppStorage("miniPlayerGlassMode") private var miniPlayerGlassMode = 0
    @AppStorage("appTheme") private var appTheme = 0
    @AppStorage("customGreeting") private var customGreeting: String = ""
    @AppStorage("showHomeWaveform") private var showHomeWaveform = true
    @AppStorage("resumePlaybackPosition") private var resumePlaybackPosition = true
    @AppStorage("removeFromListenLaterOnPlay") private var removeFromListenLaterOnPlay = true
    @AppStorage("replayGainEnabled") private var replayGainEnabled = false
    @AppStorage("menuBarEnabled") private var menuBarEnabled = true
    @AppStorage("menuBarShowOnlyWhenPlaying") private var menuBarShowOnlyWhenPlaying = true
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("albumGridDensity") private var albumGridDensity = AlbumGridDensity.comfortable.rawValue
    @AppStorage(LiquidGlassSettings.enabledKey) private var liquidGlassEnabled = true
    @EnvironmentObject var navigation: AppNavigation
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

                Toggle("Liquid Glass effects", isOn: $liquidGlassEnabled)
                Text("Uses macOS glass materials across the library, player, and controls. Turn off for a flatter, classic look.")
                    .font(.caption)
                    .foregroundColor(.secondary)
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

            Section(header: Text("Playback")) {
                Toggle("Gapless Playback", isOn: $gaplessPlayback)
                Text("Pre-schedules the next track for seamless transitions between songs.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Toggle("Resume playback position", isOn: $resumePlaybackPosition)
                Text("Remembers where you left off on each track (after 10 seconds).")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Toggle("Remove from Listen Later when played", isOn: $removeFromListenLaterOnPlay)
                Text("Clears a track from Listen Later when playback starts.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Toggle("ReplayGain volume leveling", isOn: $replayGainEnabled)
                Text("Applies track or album gain tags when available.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Crossfade")
                        Spacer()
                        Text(crossfadeDuration > 0 ? String(format: "%.0fs", crossfadeDuration) : "Off")
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $crossfadeDuration, in: 0...12, step: 1)
                    Text("Overlaps the end of each track with the next. Set to 0 to disable.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section(header: Text("Library")) {
                Toggle("Show waveform in home player bar", isOn: $showHomeWaveform)
                Picker("Album grid density", selection: $albumGridDensity) {
                    ForEach(AlbumGridDensity.allCases) { density in
                        Text(density.label).tag(density.rawValue)
                    }
                }
            }

            Section(header: Text("Menu Bar")) {
                Toggle("Show menu bar controller", isOn: $menuBarEnabled)
                Toggle("Only when music is playing", isOn: $menuBarShowOnlyWhenPlaying)
                Text("Left-click the menu bar item to play or pause. Right-click for more controls.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section(header: Text("System")) {
                Toggle("Launch Aries at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        LaunchAtLoginHelper.setEnabled(enabled)
                    }
                    .onAppear {
                        launchAtLogin = LaunchAtLoginHelper.isEnabled
                    }
            }

            Section(header: Text("Synced Lyrics Effects")) {
                Toggle("Glow Effect", isOn: $isGlowEffectEnabled)
                Toggle("Neon Effect", isOn: $isNeonEffectEnabled)
            }
        }
        .formStyle(.grouped)
        .onChange(of: navigation.focusGreetingField) { _, focus in
            guard focus else { return }
            selectGreetingText = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                selectGreetingText = false
            }
            navigation.focusGreetingField = false
        }
    }
}
