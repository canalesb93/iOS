import Combine
import Foundation
import Shared

/// Shared state of the native iOS tab bar, on when it is the chosen `FrontendNavigationStyle`.
final class NativeTabBarState: ObservableObject {
    static let shared = NativeTabBarState()

    @Published private(set) var isEnabled: Bool
    let moreRequests = PassthroughSubject<Void, Never>()

    private var cancellables = Set<AnyCancellable>()

    init(navigation: FrontendNavigationState = .shared) {
        self.isEnabled = navigation.isTabBarEnabled

        navigation.$style
            .map { $0 == .tabBar }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isEnabled in
                self?.isEnabled = isEnabled
            }
            .store(in: &cancellables)
    }

    /// The frontend's `sidebar/show`: the hamburger with no sidebar of its own to open.
    func requestMore() {
        moreRequests.send()
    }
}
