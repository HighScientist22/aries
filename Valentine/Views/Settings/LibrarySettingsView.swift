import SwiftUI

struct LibrarySettingsView: View {
    @EnvironmentObject var library: LibraryStore
    @AppStorage("scanOnLaunch") private var scanOnLaunch: Bool = true
    @AppStorage("hideDuplicateTracks") private var hideDuplicateTracks: Bool = false

    var body: some View {
        Form {
            Section(header: Text("Library Scanning")) {
                Toggle("Scan for new music on launch", isOn: $scanOnLaunch)
                Text("When enabled the app will scan configured folders on startup and watch them for changes.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section(header: Text("Identification")) {
                if library.isIdentifying {
                    ProgressView(
                        "Identifying… \(library.identificationProgress.completed)/\(library.identificationProgress.total)",
                        value: Double(library.identificationProgress.completed),
                        total: Double(max(library.identificationProgress.total, 1))
                    )
                } else {
                    Button("Identify Library with MusicBrainz") {
                        library.identifyLibrary()
                    }
                }
                Text("Matches tracks to MusicBrainz recordings using title, artist, and duration. Results are cached locally and used for duplicate detection and album versions.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Toggle("Hide duplicate tracks in browse", isOn: $hideDuplicateTracks)
                    .onChange(of: hideDuplicateTracks) { _, _ in
                        library.refreshBrowseGroups()
                    }
            }

            Section(header: Text("Watched Folders")) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(library.watchedFolders, id: \.self) { url in
                        HStack {
                            Text(url.lastPathComponent)
                                .lineLimit(1)
                            Spacer()
                            Button(role: .destructive) {
                                library.removeWatchedFolder(url)
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }

                    Button(action: addFolder) {
                        Label("Add Folder…", systemImage: "folder.badge.plus")
                    }
                    .padding(.top, 6)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func addFolder() {
        guard let url = MusicImportPanel.pickFiles(allowFolders: true, allowMultiple: false).first else { return }
        library.addWatchedFolder(url)
    }
}

struct LibrarySettingsView_Previews: PreviewProvider {
    static var previews: some View {
        LibrarySettingsView()
            .environmentObject(LibraryStore())
            .frame(width: 600, height: 400)
    }
}
