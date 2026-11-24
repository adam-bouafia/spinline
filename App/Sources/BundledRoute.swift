import Foundation
import RideEngine

/// A route shipped in the app bundle: `Routes/<id>.json` and `Routes/<id>.mp4`.
struct BundledRoute: Identifiable {
    let id: String
    let index: RouteIndex
    let videoURL: URL

    var name: String {
        id.replacingOccurrences(of: "-", with: " ").capitalized
    }

    static func all() -> [BundledRoute] {
        let indexes = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: "Routes") ?? []
        return indexes.compactMap { url in
            let id = url.deletingPathExtension().lastPathComponent
            guard let data = try? Data(contentsOf: url),
                let index = try? JSONDecoder().decode(RouteIndex.self, from: data),
                let video = Bundle.main.url(forResource: id, withExtension: "mp4", subdirectory: "Routes")
            else { return nil }
            return BundledRoute(id: id, index: index, videoURL: video)
        }
        .sorted { $0.id < $1.id }
    }
}
