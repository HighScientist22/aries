import SwiftUI

struct IntegrationsSettingsView: View {
    @ObservedObject private var lastFM = LastFMService.shared
    
    @State private var isConnecting = false
    @State private var webAuthToken: String? = nil
    @State private var errorMessage: String? = nil
    
    var body: some View {
        Form {
            Section {
                Toggle("Enable Last.fm Integration", isOn: $lastFM.isEnabled)
            } header: {
                Text("Last.fm")
            } footer: {
                Text("When enabled, Valentine will automatically share your listening history (scrobble) to your Last.fm profile.")
            }
            
            if lastFM.isEnabled {
                Section("Account Status") {
                    if lastFM.isConnected {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Connected as **\(lastFM.username)**")
                            
                            Spacer()
                            
                            Button("Disconnect", role: .destructive) {
                                lastFM.disconnect()
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("You are not connected. Connect your Last.fm account to keep track of your listening history and show what you're playing in real-time.")
                                .foregroundColor(.secondary)
                            
                            if let token = webAuthToken {
                                Text("Please authorize Valentine in your browser, then click continue.")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                
                                HStack {
                                    Button("Continue") {
                                        finishAuthentication(token: token)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(isConnecting)
                                    
                                    Button("Cancel") {
                                        webAuthToken = nil
                                        isConnecting = false
                                    }
                                    .buttonStyle(.bordered)
                                }
                            } else {
                                Button("Connect to Last.fm") {
                                    startAuthentication()
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(isConnecting)
                            }
                            
                            if let error = errorMessage {
                                Text(LocalizedStringKey(error))
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
    
    private func startAuthentication() {
        isConnecting = true
        errorMessage = nil
        
        Task {
            do {
                let token = try await lastFM.getToken()
                
                // Open browser
                DispatchQueue.main.async {
                    let apiKey = Secrets.lastFMApiKey
                    if let authURL = URL(string: "https://www.last.fm/api/auth/?api_key=\(apiKey)&token=\(token)") {
                        #if os(macOS)
                        NSWorkspace.shared.open(authURL)
                        #endif
                    }
                    self.webAuthToken = token
                    self.isConnecting = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Could not connect to Last.fm API."
                    self.isConnecting = false
                }
            }
        }
    }
    
    private func finishAuthentication(token: String) {
        isConnecting = true
        errorMessage = nil
        
        Task {
            do {
                try await lastFM.getSession(token: token)
                DispatchQueue.main.async {
                    self.webAuthToken = nil
                    self.isConnecting = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Authorization failed. Did you approve in the browser?"
                    self.isConnecting = false
                }
            }
        }
    }
}
