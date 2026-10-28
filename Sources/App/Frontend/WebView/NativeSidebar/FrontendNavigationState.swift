import Combine
import Foundation
import Shared

/// App-wide source of truth for the active `FrontendNavigationStyle`, observed by every window.
final class FrontendNavigationState: ObservableObject {
    static let shared = FrontendNavigationState()

    @Published private(set) var style: FrontendNavigationStyle

    private var cancellables = Set<AnyCancellable>()

    init() {
        self.style = FrontendNavigationStyle.current

        NotificationCenter.default.publisher(for: SettingsStore.frontendNavigationStyleDidChange)
            .map { _ in FrontendNavigationStyle.current }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] style in
                self?.style = style
            }
            .store(in: &cancellables)
    }

    var isNativeSidebarEnabled: Bool { style == .sidebar }
    var isTabBarEnabled: Bool { style == .tabBar }

    func select(_ style: FrontendNavigationStyle) {
        Current.settingsStore.frontendNavigationStyle = style.rawValue
    }
}
