//
//  MetadataWriter.swift
//  Aries
//

import Foundation

enum MetadataWriter {
    static func writeMetadata(to url: URL, metadata: EditableTrackMetadata) async throws {
        let script = """
import sys
import os

mutagen_path = sys.argv[1]
sys.path.insert(0, mutagen_path)

import mutagen

def set_metadata(file_path, fields):
    f = mutagen.File(file_path)
    if f is None:
        print("Unsupported file format")
        sys.exit(1)

    tags = f.tags
    if tags is None:
        f.add_tags()
        tags = f.tags

    title = fields.get("title", "")
    artist = fields.get("artist", "")
    album = fields.get("album", "")
    genre = fields.get("genre", "")
    year = fields.get("year", "")
    track = fields.get("track", "")
    disc = fields.get("disc", "")
    composer = fields.get("composer", "")

    tag_type = type(tags).__name__

    if tag_type == "ID3":
        from mutagen.id3 import TIT2, TPE1, TALB, TCON, TDRC, TRCK, TPOS, TCOM
        tags["TIT2"] = TIT2(encoding=3, text=title)
        tags["TPE1"] = TPE1(encoding=3, text=artist)
        if album:
            tags["TALB"] = TALB(encoding=3, text=album)
        if genre:
            tags["TCON"] = TCON(encoding=3, text=genre)
        if year:
            tags["TDRC"] = TDRC(encoding=3, text=year)
        if track:
            tags["TRCK"] = TRCK(encoding=3, text=track)
        if disc:
            tags["TPOS"] = TPOS(encoding=3, text=disc)
        if composer:
            tags["TCOM"] = TCOM(encoding=3, text=composer)
    elif tag_type == "MP4Tags":
        tags["\\xa9nam"] = title
        tags["\\xa9ART"] = artist
        if album:
            tags["\\xa9alb"] = album
        if genre:
            tags["\\xa9gen"] = genre
        if year:
            tags["\\xa9day"] = year
        if track:
            try:
                tags["trkn"] = [(int(track.split("/")[0]), 0)]
            except:
                pass
        if disc:
            try:
                tags["disk"] = [(int(disc.split("/")[0]), 0)]
            except:
                pass
        if composer:
            tags["\\xa9wrt"] = composer
    elif tag_type in ["VCFLACDict", "VCOggDict"]:
        tags["TITLE"] = title
        tags["ARTIST"] = artist
        if album:
            tags["ALBUM"] = album
        if genre:
            tags["GENRE"] = genre
        if year:
            tags["DATE"] = year
        if track:
            tags["TRACKNUMBER"] = track
        if disc:
            tags["DISCNUMBER"] = disc
        if composer:
            tags["COMPOSER"] = composer
    else:
        try:
            tags["TITLE"] = title
            tags["ARTIST"] = artist
            if album:
                tags["ALBUM"] = album
        except Exception as e:
            print(str(e))
            sys.exit(1)

    f.save()

if __name__ == "__main__":
    if len(sys.argv) < 4:
        sys.exit(1)
    file_path = sys.argv[2]
    fields = {
        "title": sys.argv[3],
        "artist": sys.argv[4],
        "album": sys.argv[5],
        "genre": sys.argv[6],
        "year": sys.argv[7],
        "track": sys.argv[8],
        "disc": sys.argv[9],
        "composer": sys.argv[10],
    }
    set_metadata(file_path, fields)
"""
        let tempDir = FileManager.default.temporaryDirectory
        let scriptURL = tempDir.appendingPathComponent("write_metadata.py")
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        let mutagenPath = MutagenInstallerService.mutagenLibraryPath
        process.arguments = [
            "python3", scriptURL.path, mutagenPath, url.path,
            metadata.title, metadata.artist, metadata.album,
            metadata.genre, metadata.year, metadata.trackNumber,
            metadata.discNumber, metadata.composer
        ]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if process.terminationStatus != 0 {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "MetadataWriter", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: errorString])
        }
    }
}
