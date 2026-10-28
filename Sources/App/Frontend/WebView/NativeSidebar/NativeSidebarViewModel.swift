import Combine
import PromiseKit
import Shared
import SwiftUI

/// Everything the native sidebar shows and does, on top of the panel data `MacSidebarViewModel` maintains.
@MainActor
final class NativeSidebarViewModel: ObservableObject {
    static let appSettingsTransitionID = "nativeSidebarAppSettings"
    static let serverTransitionID = "nativeSidebarServer"

    let sidebar: MacSidebarViewModel
    let drawer = NativeSidebarDrawerState()

    @Published private(set) var selectedItemId: String?
    @Published private(set) var currentPath: String?
    @Published var isEditing = false

    var onNavigate: ((String) -> Void)?
    var onQuickSearch: (() -> Void)?
    var onAssist: (() -> Void)?
    var onShowNotifications: (() -> Void)?
    var appCoordinator: () -> Guarantee<AppCoordinator> = { Current.sceneManager.appCoordinator }

    private let allServers: () -> [Server]
    private var cancellables = Set<AnyCancellable>()

    init(
        sidebar: MacSidebarViewModel,
        overlayState: WebFrontendOverlayState,
        servers: @escaping () -> [Server] = { Current.servers.all }
    ) {
        self.sidebar = sidebar
        self.allServers = servers

        sidebar.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        overlayState.$currentPath
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] path in
                guard let self else { return }
                currentPath = path
                let itemId = NativeSidebarRoute.itemId(forPath: path)
                guard itemId != selectedItemId else { return }
                withAnimation(DesignSystem.Motion.snappy) {
                    self.selectedItemId = itemId
                }
            }
            .store(in: &cancellables)
    }

    var server: Server { sidebar.server }
    var mainItems: [MacSidebarItem] { sidebar.mainItems }
    var hiddenItems: [MacSidebarItem] { sidebar.hiddenItems }

    /// The Home Assistant settings panel, shown to admins only.
    var settingsItem: MacSidebarItem? {
        sidebar.fixedItems.first { $0.id == MacSidebarItemsBuilder.settingsPanelPath }
    }

    var notificationsItem: MacSidebarItem? {
        sidebar.fixedItems.first { $0.kind == .notifications }
    }

    var profileItem: MacSidebarItem? {
        sidebar.fixedItems.first { $0.kind == .profile }
    }

    var notificationsCount: Int {
        notificationsItem?.badge ?? 0
    }

    var isAtPanelRoot: Bool {
        NativeSidebarRoute.isRoot(currentPath)
    }

    // MARK: - Actions

    func select(_ item: MacSidebarItem) {
        switch item.kind {
        case .notifications:
            drawer.close()
            onShowNotifications?()
        case .panel, .profile:
            guard let path = item.navigationPath else { return }
            withAnimation(DesignSystem.Motion.snappy) {
                selectedItemId = item.id
            }
            drawer.close()
            // Re-selecting the current panel's row takes it back to its top, like re-tapping a tab.
            onNavigate?(path)
        }
    }

    func quickSearch() {
        drawer.close()
        onQuickSearch?()
    }

    func assist() {
        drawer.close()
        onAssist?()
    }

    func showAppSettings(using presenter: AppSettingsPresenter?) {
        presenter?.presentSettings(zoomingFrom: Self.appSettingsTransitionID)
    }

    // MARK: - Servers

    var servers: [Server] { allServers() }

    var hasMultipleServers: Bool { servers.count > 1 }

    func open(server: Server) {
        guard server.identifier != self.server.identifier else { return }
        drawer.close()
        appCoordinator().done { $0.open(server: server) }
    }

    // MARK: - Editing

    func canHide(_ item: MacSidebarItem) -> Bool {
        sidebar.canHide(item)
    }

    func hide(_ item: MacSidebarItem) {
        withAnimation(DesignSystem.Motion.smooth) {
            sidebar.hide(itemId: item.id)
        }
    }

    func show(_ item: MacSidebarItem) {
        withAnimation(DesignSystem.Motion.smooth) {
            sidebar.show(itemId: item.id)
        }
    }

    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        var ids = mainItems.map(\.id)
        ids.move(fromOffsets: source, toOffset: destination)
        sidebar.reorderItems(to: ids)
    }
}
