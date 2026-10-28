import Foundation

/// JavaScript that hands the frontend's menu button to the native sidebar.
///
/// The frontend only shows its menu button when it owns a drawer, and hides it as soon as an app reports
/// `hasSidebar`. Instead the app keeps `hasSidebar` off, tells the frontend its docked sidebar is hidden (so
/// the button shows at every width, even on iPad), and intercepts the button's `hass-toggle-menu` event on
/// its way down to `home-assistant-main`, forwarding it as the same `sidebar/show` message an external
/// sidebar would get.
enum NativeSidebarBridgeScript {
    /// Marks a `dockedSidebar` value the app wrote, so switching back to the web menu can undo it without
    /// touching a choice the user made in the frontend.
    private static let markerKey = "haNativeSidebarOwnsDockedSidebar"

    static let install = """
    (function () {
        try {
            if (localStorage.getItem("\(markerKey)") !== "1") {
                const previous = localStorage.getItem("dockedSidebar");
                localStorage.setItem("\(markerKey)Previous", previous === null ? "" : previous);
            }
            localStorage.setItem("dockedSidebar", JSON.stringify("always_hidden"));
            localStorage.setItem("\(markerKey)", "1");
        } catch (e) {}
        document.addEventListener("hass-toggle-menu", function (event) {
            event.stopImmediatePropagation();
            try {
                window.webkit.messageHandlers.externalBus.postMessage({ type: "sidebar/show", id: -1 });
            } catch (e) {}
        }, true);
    })();
    """

    static let uninstall = """
    (function () {
        try {
            if (localStorage.getItem("\(markerKey)") === "1") {
                const previous = localStorage.getItem("\(markerKey)Previous");
                if (previous) {
                    localStorage.setItem("dockedSidebar", previous);
                } else {
                    localStorage.removeItem("dockedSidebar");
                }
                localStorage.removeItem("\(markerKey)");
                localStorage.removeItem("\(markerKey)Previous");
            }
        } catch (e) {}
    })();
    """
}
