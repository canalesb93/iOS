import Foundation

/// Reads a frontend path the way the sidebar thinks about it: which row it belongs to, and whether it is the
/// top of that panel (where the left edge opens the drawer) or a page below it (where the left edge goes back).
enum NativeSidebarRoute {
    /// Panels whose second path segment is still a top-level destination: dashboard views (`/lovelace/1`),
    /// and the stand-alone panels that encode filters rather than depth in their path.
    private static let flatPanels: Set<String> = [
        "lovelace", "home", "map", "energy", "logbook", "history", "calendar", "todo", "media-browser", "profile",
    ]

    /// Top-level pages of the settings panel; anything deeper shows a back arrow in the frontend.
    private static let configRoots: Set<String> = ["dashboard"]

    static func itemId(forPath path: String?) -> String? {
        MacSidebarItemsBuilder.itemId(forPath: path)
    }

    static func isRoot(_ path: String?) -> Bool {
        guard let path else { return true }
        let segments = path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        guard let first = segments.first else { return true }
        if segments.count == 1 {
            return true
        }
        if first == "config" {
            return segments.count == 2 && configRoots.contains(segments[1])
        }
        if flatPanels.contains(first) {
            // `/energy/now`, `/lovelace/kitchen`, `/media-browser/browser/...` (one level of browsing is still top).
            return segments.count == 2
        }
        // Custom dashboards (`/dashboard-kitchen/0`) behave like Lovelace: the second segment is a view.
        return segments.count == 2 && first.contains("-")
    }
}
