import Foundation
@testable import HomeAssistant
@testable import Shared
import Testing

@Suite(.serialized)
@MainActor
struct FrontendNavigationStyleTests {
    /// Runs `body` with a stored preference, restoring whatever was there before.
    private func withStoredRawValue(_ rawValue: String?, _ body: () -> Void) {
        let key = "frontendNavigationStyle"
        let prefs = Current.settingsStore.prefs
        let previous = prefs.object(forKey: key)
        defer {
            if let previous {
                prefs.set(previous, forKey: key)
            } else {
                prefs.removeObject(forKey: key)
            }
        }
        if let rawValue {
            prefs.set(rawValue, forKey: key)
        } else {
            prefs.removeObject(forKey: key)
        }
        body()
    }

    @Test func rawValuesMapToStyles() {
        #expect(FrontendNavigationStyle(rawValue: "sidebar") == .sidebar)
        #expect(FrontendNavigationStyle(rawValue: "tabBar") == .tabBar)
        #expect(FrontendNavigationStyle(rawValue: "web") == .web)
        #expect(FrontendNavigationStyle(rawValue: "somethingNew") == nil)
    }

    @Test func unknownIsNeverOfferedInSettings() {
        #expect(!FrontendNavigationStyle.selectableStyles.contains(.unknown))
        #expect(!FrontendNavigationStyle.unknown.isAvailableOnThisDevice)
    }

    @Test func unknownStoredValueFallsBackToAnAvailableDefault() throws {
        try #require(!Current.isCatalyst)
        withStoredRawValue("a-style-from-a-newer-build") {
            let resolved = FrontendNavigationStyle.current
            #expect(resolved != .unknown)
            #expect(resolved.isAvailableOnThisDevice)
            #expect(resolved == .default)
        }
    }

    @Test func storedWebStyleIsKept() {
        withStoredRawValue("web") {
            #expect(FrontendNavigationStyle.current == .web)
        }
    }

    @Test func storedSidebarStyleIsKept() throws {
        try #require(!Current.isCatalyst)
        withStoredRawValue("sidebar") {
            #expect(FrontendNavigationStyle.current == .sidebar)
        }
    }

    @Test func unknownTitleMatchesTheDefaultsTitle() {
        #expect(FrontendNavigationStyle.unknown.title == FrontendNavigationStyle.sidebar.title)
    }
}
