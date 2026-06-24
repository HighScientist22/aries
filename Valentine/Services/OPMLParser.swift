//
//  OPMLParser.swift
//  Aries
//

import Foundation

enum OPMLParser {
    static func parse(data: Data) throws -> [String] {
        let delegate = OPMLDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else {
            throw parser.parserError ?? NSError(domain: "OPMLParser", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to parse OPML"
            ])
        }
        return delegate.feedURLs
    }

    static func parseFile(at url: URL) throws -> [String] {
        try parse(data: Data(contentsOf: url))
    }
}

private final class OPMLDelegate: NSObject, XMLParserDelegate {
    var feedURLs: [String] = []

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        guard elementName.lowercased() == "outline" else { return }
        if let feed = attributeDict["xmlUrl"] ?? attributeDict["xmlurl"] ?? attributeDict["url"],
           feed.contains("://") {
            feedURLs.append(feed)
        }
    }
}
