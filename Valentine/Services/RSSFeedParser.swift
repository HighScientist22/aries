//
//  RSSFeedParser.swift
//  Aries
//

import Foundation

enum RSSFeedParser {
    static func parse(data: Data) throws -> ParsedPodcastFeed {
        let delegate = RSSParserDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse(), let feed = delegate.result else {
            throw parser.parserError ?? NSError(domain: "RSSFeedParser", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to parse feed"
            ])
        }
        return feed
    }

    static func fetchAndParse(url: URL) async throws -> ParsedPodcastFeed {
        var request = URLRequest(url: url)
        request.setValue("Aries/1.2", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw NSError(domain: "RSSFeedParser", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Feed request failed"
            ])
        }
        return try parse(data: data)
    }
}

private final class RSSParserDelegate: NSObject, XMLParserDelegate {
    var result: ParsedPodcastFeed?

    private var inChannel = false
    private var inItem = false
    private var inImage = false
    private var currentText = ""

    private var channelTitle = ""
    private var channelAuthor = ""
    private var channelDescription = ""
    private var channelImageURL = ""

    private var itemGuid = ""
    private var itemTitle = ""
    private var itemDescription = ""
    private var itemPubDate = ""
    private var itemEnclosureURL = ""
    private var itemDuration = ""
    private var episodes: [ParsedPodcastEpisode] = []

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        let element = elementName.lowercased()
        currentText = ""

        switch element {
        case "channel":
            inChannel = true
        case "item":
            inItem = true
            itemGuid = ""
            itemTitle = ""
            itemDescription = ""
            itemPubDate = ""
            itemEnclosureURL = ""
            itemDuration = ""
        case "enclosure" where inItem:
            if let url = attributeDict["url"] {
                itemEnclosureURL = url
            }
        case "image" where inChannel:
            inImage = true
        case "itunes:image" where inChannel:
            if let href = attributeDict["href"] {
                channelImageURL = href
            }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let element = elementName.lowercased()
        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        if element == "channel" {
            inChannel = false
            result = ParsedPodcastFeed(
                title: channelTitle.isEmpty ? "Podcast" : channelTitle,
                author: channelAuthor.isEmpty ? nil : channelAuthor,
                description: channelDescription.isEmpty ? nil : channelDescription,
                artworkURL: channelImageURL.isEmpty ? nil : channelImageURL,
                episodes: episodes
            )
        } else if element == "item" {
            inItem = false
            guard !itemEnclosureURL.isEmpty else { return }
            let guid = itemGuid.isEmpty ? (itemTitle + itemEnclosureURL) : itemGuid
            episodes.append(ParsedPodcastEpisode(
                guid: guid,
                title: itemTitle.isEmpty ? "Episode" : itemTitle,
                description: itemDescription.isEmpty ? nil : itemDescription,
                publishDate: parseDate(itemPubDate),
                enclosureURL: itemEnclosureURL,
                duration: parseDuration(itemDuration)
            ))
        } else if inChannel && !inItem {
            switch element {
            case "title" where channelTitle.isEmpty: channelTitle = text
            case "itunes:author", "author" where channelAuthor.isEmpty: channelAuthor = text
            case "description", "itunes:summary" where channelDescription.isEmpty: channelDescription = text
            case "url" where inImage && channelImageURL.isEmpty: channelImageURL = text
            case "image": inImage = false
            default: break
            }
        } else if inItem {
            switch element {
            case "title": itemTitle = text
            case "guid": itemGuid = text
            case "description", "itunes:summary", "content:encoded" where itemDescription.isEmpty:
                itemDescription = text
            case "pubdate": itemPubDate = text
            case "itunes:duration": itemDuration = text
            default: break
            }
        }
    }

    private func parseDate(_ raw: String) -> Date? {
        let formats = [
            "EEE, dd MMM yyyy HH:mm:ss Z",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd"
        ]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: raw) { return date }
        }
        return nil
    }

    private func parseDuration(_ raw: String) -> TimeInterval? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let seconds = TimeInterval(trimmed) { return seconds }
        let parts = trimmed.split(separator: ":").map(String.init)
        guard !parts.isEmpty else { return nil }
        var total: TimeInterval = 0
        for part in parts {
            guard let value = TimeInterval(part) else { return nil }
            total = total * 60 + value
        }
        return total
    }
}
