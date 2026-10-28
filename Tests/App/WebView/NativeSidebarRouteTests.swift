@testable import HomeAssistant
import Testing

struct NativeSidebarRouteTests {
    @Test(
        "Panel roots open the drawer from the left edge, deeper pages go back",
        arguments: [
            ("/lovelace/0", true),
            ("/home", true),
            ("/config/dashboard", true),
            ("/config/areas/dashboard", false),
            ("/config/areas/area/kitchen", false),
            ("/dashboard-kitchen/0", true),
            ("/dashboard-kitchen/0/extra", false),
            ("/energy/now", true),
            ("/history", true),
            ("/", true),
            ("", true),
        ] as [(String, Bool)]
    )
    func isRoot(path: String, expected: Bool) {
        #expect(NativeSidebarRoute.isRoot(path) == expected)
    }

    @Test func aMissingPathIsARoot() {
        #expect(NativeSidebarRoute.isRoot(nil))
    }

    @Test func deeperPagesOfOtherPanelsAreNotRoots() {
        #expect(!NativeSidebarRoute.isRoot("/developer-tools/state/extra"))
        #expect(!NativeSidebarRoute.isRoot("/config/integrations"))
    }

    @Test(
        "The selected row is the first path segment",
        arguments: [
            ("/lovelace/0", "lovelace"),
            ("/config/areas/dashboard", "config"),
            ("/dashboard-kitchen/0", "dashboard-kitchen"),
            ("/history", "history"),
        ] as [(String, String)]
    )
    func itemId(path: String, expected: String) {
        #expect(NativeSidebarRoute.itemId(forPath: path) == expected)
    }

    @Test func itemIdIsNilWithoutAPath() {
        #expect(NativeSidebarRoute.itemId(forPath: nil) == nil)
        #expect(NativeSidebarRoute.itemId(forPath: "/") == nil)
    }
}
