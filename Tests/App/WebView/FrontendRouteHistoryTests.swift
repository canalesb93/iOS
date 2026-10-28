@testable import HomeAssistant
import Testing

struct FrontendRouteHistoryTests {
    @Test func theFirstPathResets() {
        var history = FrontendRouteHistory()
        let change = history.update(to: "/config/dashboard")
        #expect(change == .reset)
        #expect(history.stack == ["/config/dashboard"])
    }

    @Test func theSamePathAgainIsNone() {
        var history = FrontendRouteHistory()
        history.update(to: "/config/dashboard")
        let change = history.update(to: "/config/dashboard")
        #expect(change == .none)
        #expect(history.stack == ["/config/dashboard"])
    }

    @Test func aSubPageOfARootPushes() {
        var history = FrontendRouteHistory()
        history.update(to: "/config/dashboard")
        let change = history.update(to: "/config/areas/dashboard")
        #expect(change == .push(from: "/config/dashboard"))
        #expect(history.canPop)
        #expect(history.previous == "/config/dashboard")
        #expect(history.current == "/config/areas/dashboard")
    }

    @Test func goingBackToThePreviousPathPops() {
        var history = FrontendRouteHistory()
        history.update(to: "/config/dashboard")
        history.update(to: "/config/areas/dashboard")
        let change = history.update(to: "/config/dashboard")
        #expect(change == .pop(from: "/config/areas/dashboard"))
        #expect(history.stack == ["/config/dashboard"])
        #expect(!history.canPop)
    }

    @Test func jumpingBackTwoLevelsPopsToTheFirstPath() {
        var history = FrontendRouteHistory()
        history.update(to: "/config/dashboard")
        history.update(to: "/config/areas/dashboard")
        history.update(to: "/config/areas/area/kitchen")
        let change = history.update(to: "/config/dashboard")
        #expect(change == .pop(from: "/config/areas/area/kitchen"))
        #expect(history.stack == ["/config/dashboard"])
    }

    @Test func aDifferentRootResets() {
        var history = FrontendRouteHistory()
        history.update(to: "/config/dashboard")
        history.update(to: "/config/areas/dashboard")
        let change = history.update(to: "/map")
        #expect(change == .reset)
        #expect(history.stack == ["/map"])
    }

    @Test func expectsReplaceResetsOntoASubPageAndClearsTheFlag() {
        var history = FrontendRouteHistory()
        history.update(to: "/config/dashboard")
        history.expectsReplace = true
        let change = history.update(to: "/config/areas/dashboard")
        #expect(change == .reset)
        #expect(history.stack == ["/config/areas/dashboard"])
        #expect(!history.expectsReplace)
    }

    @Test func aDifferentDashboardViewResets() {
        var history = FrontendRouteHistory()
        history.update(to: "/lovelace/0")
        let change = history.update(to: "/lovelace/1")
        #expect(change == .reset)
        #expect(history.stack == ["/lovelace/1"])
    }

    @Test func aRedirectReplacesThePageItForwardedFrom() {
        var history = FrontendRouteHistory()
        history.update(to: "/config/dashboard")
        history.update(to: "/config/areas")
        let change = history.update(to: "/config/areas/dashboard", isRedirect: true)
        #expect(change == .none)
        #expect(history.stack == ["/config/dashboard", "/config/areas/dashboard"])
        #expect(history.previous == "/config/dashboard")
    }

    @Test func aRedirectWithOneEntryIsAPush() {
        var history = FrontendRouteHistory()
        history.update(to: "/config/dashboard")
        let change = history.update(to: "/config/areas/dashboard", isRedirect: true)
        #expect(change == .push(from: "/config/dashboard"))
        #expect(history.stack == ["/config/dashboard", "/config/areas/dashboard"])
    }
}
