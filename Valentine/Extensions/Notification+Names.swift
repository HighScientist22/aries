import Foundation

extension Notification.Name {
    static let addFile = Notification.Name("AddFile")
    static let addFolder = Notification.Name("AddFolder")
    static let clearPlaylist = Notification.Name("ClearPlaylist")
    static let editLyrics = Notification.Name("EditLyrics")
    static let reinstallMutagen = Notification.Name("ReinstallMutagen")
    static let openLibrarySearch = Notification.Name("OpenLibrarySearch")
    static let showKeyboardShortcuts = Notification.Name("ShowKeyboardShortcuts")
    static let openSettings = Notification.Name("OpenSettings")
    static let openAlbumFromSearch = Notification.Name("OpenAlbumFromSearch")
    static let openArtistFromSearch = Notification.Name("OpenArtistFromSearch")
    static let quickLookTrack = Notification.Name("QuickLookTrack")
    static let openAudioFiles = Notification.Name("OpenAudioFiles")
}
