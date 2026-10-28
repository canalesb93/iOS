import Foundation
import Shared

/// How the app lets people move between the frontend's panels.
enum FrontendNavigationStyle: String, CaseIterable, Identifiable {
    /// A native drawer on iPhone and a docked column on iPad.
    case sidebar
    /// The iOS 26 native tab bar.
    case tabBar
    /// The frontend's own hamburger drawer, as upstream ships it.
    case web
    /// A value written by a newer build; resolves to the default.
    case unknown

    static let `default`: FrontendNavigationStyle = .sidebar

    var id: String { rawValue }

    /// The styles offered in Settings on this device.
    static var selectableStyles: [FrontendNavigationStyle] {
        [.sidebar, .tabBar, .web].filter(\.isAvailableOnThisDevice)
    }

    var title: String {
        switch self {
        case .sidebar, .unknown: return L10n.SettingsDetails.General.Navigation.Style.sidebar
        case .tabBar: return L10n.SettingsDetails.General.Navigation.Style.tabBar
        case .web: return L10n.SettingsDetails.General.Navigation.Style.web
        }
    }

    var isAvailableOnThisDevice: Bool {
        switch self {
        case .sidebar:
            // The Mac keeps its toolbar-driven window chrome.
            return !Current.isCatalyst
        case .tabBar:
            if #available(iOS 26, *) {
                return !Current.isCatalyst
            }
            return false
        case .web:
            return true
        case .unknown:
            return false
        }
    }

    /// Someone who turned the tab bar on in App Labs, before it became a navigation style, keeps it.
    private static var migratedDefault: FrontendNavigationStyle {
        Current.appLabs.enabledFeatureIds.contains(AppLabsFeature.iosNativeTabBar.rawValue) ? .tabBar : .default
    }

    /// The stored preference, falling back to the best style this device supports.
    static var current: FrontendNavigationStyle {
        let stored = Current.settingsStore.frontendNavigationStyle
            .map { FrontendNavigationStyle(rawValue: $0) ?? .unknown } ?? migratedDefault
        if stored.isAvailableOnThisDevice {
            return stored
        }
        return FrontendNavigationStyle.default.isAvailableOnThisDevice ? .default : .web
    }
}
