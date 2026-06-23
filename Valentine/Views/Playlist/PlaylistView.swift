import SwiftUI
import AppKit

struct PlaylistView: View {
    @ObservedObject var engine: AudioEngine
    @EnvironmentObject var library: LibraryStore
    @EnvironmentObject var navigation: AppNavigation

    @State private var searchText = ""
    @State private var isSearchVisible = false
    @State private var isSelectionMode = false
    @State private var selectedTracks = Set<UUID>()
    @State private var cachedQueueGreeting: String = ""

    private var filteredTracks: [(Int, Track)] {
        let enumerated = Array(engine.queue.enumerated())
        if searchText.isEmpty {
            return enumerated
        }
        return enumerated.filter {
            $0.element.title.localizedCaseInsensitiveContains(searchText)
                || $0.element.artist.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var upNextCount: Int {
        guard let current = engine.currentTrackIndex else { return engine.queue.count }
        return max(0, engine.queue.count - current - 1)
    }

    private func sidebarGreeting() -> String {
        if let custom = UserDefaults.standard.string(forKey: "customGreeting"),
           !custom.trimmingCharacters(in: .whitespaces).isEmpty {
            return custom
        }
        let hour = Calendar.current.component(.hour, from: Date())
        let timeGreeting: String
        switch hour {
        case 5..<12: timeGreeting = "Morning"
        case 12..<18: timeGreeting = "Afternoon"
        default: timeGreeting = "Evening"
        }
        let fullName = NSFullUserName()
        let first = fullName.split(separator: " ").first.map(String.init) ?? fullName
        return "\(timeGreeting), \(first)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            queueHeader

            queueToolbar

            if isSelectionMode && !selectedTracks.isEmpty {
                deleteSelectionBar
            }

            if filteredTracks.isEmpty {
                emptyQueue
            } else {
                queueList
            }
        }
        .onAppear {
            if cachedQueueGreeting.isEmpty {
                cachedQueueGreeting = sidebarGreeting()
            }
        }
    }

    private var queueHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(cachedQueueGreeting.isEmpty ? sidebarGreeting() : cachedQueueGreeting)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.accentColor)
                Text("Queue · \(engine.queue.count) tracks · \(upNextCount) up next")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button {
                navigation.openSettings(tab: .general, focusGreeting: true)
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.plain)
            .help("Edit Greeting")
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var queueToolbar: some View {
        HStack {
            if !isSearchVisible {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Up Next")
                        .font(.headline)
                    Text(remainingLabel)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                searchField
            }

            toolbarButton(
                icon: "magnifyingglass",
                isActive: isSearchVisible,
                help: isSearchVisible ? "Close Search" : "Search Queue"
            ) {
                withAnimation {
                    isSearchVisible.toggle()
                    if !isSearchVisible { searchText = "" }
                }
            }
            .keyboardShortcut("f", modifiers: .command)

            toolbarButton(
                icon: isSelectionMode ? "checkmark.circle.fill" : "checkmark.circle",
                isActive: isSelectionMode,
                help: isSelectionMode ? "Exit Selection Mode" : "Select Tracks"
            ) {
                withAnimation {
                    isSelectionMode.toggle()
                    if !isSelectionMode { selectedTracks.removeAll() }
                }
            }

            if !engine.queue.isEmpty {
                toolbarButton(icon: "trash", isActive: false, help: "Clear Queue") {
                    withAnimation { engine.clearPlaylist() }
                }
            }
        }
        .padding()
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 14))
            TextField("Search queue…", text: $searchText)
                .textFieldStyle(.plain)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.medium)
                .fill(.clear)
                .liquidGlass(cornerRadius: DesignConstants.CornerRadius.medium)
        )
        .padding(.trailing, 8)
    }

    private func toolbarButton(
        icon: String,
        isActive: Bool,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(isActive ? .accentColor : .primary)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .liquidGlass(cornerRadius: DesignConstants.CornerRadius.medium)
        .help(help)
        .padding(.trailing, 4)
    }

    private var remainingLabel: String {
        let remaining = max(0, engine.duration - engine.currentTime)
        let start = (engine.currentTrackIndex ?? -1) + 1
        let queueRemaining = filteredTracks
            .filter { $0.0 >= start }
            .map(\.1.duration)
            .reduce(0, +)
        let total = remaining + queueRemaining
        return "\(Int(total / 60)) min remaining"
    }

    private var deleteSelectionBar: some View {
        Button {
            withAnimation {
                engine.removeTracks(withIds: selectedTracks)
                selectedTracks.removeAll()
                isSelectionMode = false
            }
        } label: {
            HStack {
                Spacer()
                Image(systemName: "trash")
                Text("Delete \(selectedTracks.count)")
                Spacer()
            }
            .padding(8)
            .foregroundColor(.white)
            .background(Color.red.opacity(0.8))
            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.delete, modifiers: .command)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private var emptyQueue: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: isSearchVisible ? "magnifyingglass" : "list.bullet.rectangle")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            Text(isSearchVisible ? "No results found" : "Queue is empty")
                .font(.headline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var queueList: some View {
        List {
            if let currentIndex = engine.currentTrackIndex, engine.queue.indices.contains(currentIndex) {
                Section("Now Playing") {
                    queueRow(index: currentIndex, track: engine.queue[currentIndex])
                }
            }

            let upcoming = filteredTracks.filter { index, _ in
                guard let current = engine.currentTrackIndex else { return true }
                return index != current
            }

            if !upcoming.isEmpty {
                Section("Up Next") {
                    ForEach(upcoming, id: \.1.id) { index, track in
                        queueRow(index: index, track: track)
                    }
                    .onMove { source, destination in
                        guard !isSearchVisible, !isSelectionMode,
                              let fromLocal = source.first else { return }
                        let fromQueueIndex = upcoming[fromLocal].0
                        let toQueueIndex: Int
                        if destination >= upcoming.count {
                            toQueueIndex = (upcoming.last?.0 ?? fromQueueIndex) + 1
                        } else {
                            toQueueIndex = upcoming[destination].0
                        }
                        engine.moveQueue(from: IndexSet([fromQueueIndex]), to: toQueueIndex)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private func queueRow(index: Int, track: Track) -> some View {
        QueueRowView(
            track: track,
            isPlaying: engine.currentTrackIndex == index,
            isSelectionMode: isSelectionMode,
            isSelected: selectedTracks.contains(track.id)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelectionMode {
                toggleSelection(track.id)
            } else {
                engine.playTrack(at: index)
            }
        }
        .contextMenu {
            if engine.currentTrackIndex != index {
                Button {
                    engine.playTrack(at: index)
                } label: {
                    Label("Play Now", systemImage: "play.fill")
                }
            }

            Button {
                engine.playNextInQueue(track.id)
            } label: {
                Label("Play Next", systemImage: "text.insert")
            }

            if let libraryID = engine.libraryTrackID(at: index),
               let libraryTrack = library.tracks.first(where: { $0.id == libraryID }),
               let albumGroup = library.albumGroup(for: libraryTrack) {
                Button {
                    engine.playFromLibrary(albumGroup.tracks, startIndex: 0, store: library)
                } label: {
                    Label("Play Album", systemImage: "play.circle.fill")
                }
            }

            Button {
                NSWorkspace.shared.activateFileViewerSelecting([track.url])
            } label: {
                Label("Show in Finder", systemImage: "folder")
            }

            Divider()

            Button(role: .destructive) {
                engine.removeTracks(withIds: [track.id])
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
    }

    private func toggleSelection(_ id: UUID) {
        if selectedTracks.contains(id) {
            selectedTracks.remove(id)
        } else {
            selectedTracks.insert(id)
        }
    }
}
