import ArgumentParser
import Foundation
import RideEngine

#if canImport(FoundationXML)
    import FoundationXML
#endif

@main
struct RouteIndexTool: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "route-index",
        abstract: "Turn a GPX track into a route index: distance and gradient for each second of video."
    )

    @Option(help: "GPX file recorded while filming.")
    var gpx: String

    @Option(help: "Seconds from the first GPX point to the first video frame (negative if the video started first).")
    var offset = 0.0

    @Option(help: "Video length in seconds (ffprobe shows it).")
    var duration: Double

    @Option(help: "Output JSON file.")
    var output: String

    func run() throws {
        let track = try GPXReader.read(URL(fileURLWithPath: gpx))
        guard let first = track.first else { throw ValidationError("no track points in \(gpx)") }
        let route = try RouteBuilder.index(track: track, videoStart: first.time + offset, videoDuration: duration)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(route).write(to: URL(fileURLWithPath: output))
        print(
            String(
                format: "%d points, %.0f m, gradient %.1f to %.1f %%",
                route.points.count, route.totalDistance,
                route.points.map(\.grade).min() ?? 0, route.points.map(\.grade).max() ?? 0
            )
        )
    }
}

/// Reads `<trkpt lat lon><ele/><time/></trkpt>` elements from a GPX file.
final class GPXReader: NSObject, XMLParserDelegate {
    private var points: [TrackPoint] = []
    private var latitude = 0.0
    private var longitude = 0.0
    private var elevation = 0.0
    private var time = 0.0
    private var text = ""
    private let dates = ISO8601DateFormatter()

    static func read(_ url: URL) throws -> [TrackPoint] {
        guard let parser = XMLParser(contentsOf: url) else { throw ValidationError("cannot open \(url.path)") }
        let reader = GPXReader()
        parser.delegate = reader
        guard parser.parse() else {
            throw ValidationError("invalid GPX: \(parser.parserError.map(String.init(describing:)) ?? "")")
        }
        return reader.points
    }

    func parser(
        _ parser: XMLParser,
        didStartElement name: String,
        namespaceURI: String?,
        qualifiedName: String?,
        attributes: [String: String] = [:]
    ) {
        text = ""
        if name == "trkpt" {
            latitude = Double(attributes["lat"] ?? "") ?? 0
            longitude = Double(attributes["lon"] ?? "") ?? 0
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        text += string
    }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch name {
        case "ele": elevation = Double(value) ?? elevation
        case "time": time = dates.date(from: value)?.timeIntervalSince1970 ?? time
        case "trkpt":
            points.append(TrackPoint(time: time, latitude: latitude, longitude: longitude, elevation: elevation))
        default: break
        }
    }
}
