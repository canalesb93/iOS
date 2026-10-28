import SFSafeSymbols
import Shared
import SwiftUI

/// The sidebar itself: who and where you are, quick actions, the server's panels, and the fixed destinations.
struct NativeSidebarView: View {
    private enum Constants {
        static let avatarSize: CGFloat = 40
        static let quickActionHeight: CGFloat = 44
        static let selectionCornerRadius: CGFloat = 14
        static let selectionID = "selection"
        static let settingsIconSize: CGFloat = 20
    }

    @ObservedObject var viewModel: NativeSidebarViewModel
    let accentColor: Color

    @Environment(\.appSettingsPresenter) private var appSettingsPresenter
    @Environment(\.serverSelectionNamespace) private var transitionNamespace
    @Namespace private var selectionNamespace
    @State private var isShowingEditor = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: the account and server, with app settings beside it.
            HStack(spacing: DesignSystem.Spaces.oneAndHalf) {
                Menu {
                    if let profile = viewModel.profileItem {
                        Button {
                            viewModel.select(profile)
                        } label: {
                            Label(L10n.TabBar.More.editProfile, systemSymbol: .personCropCircle)
                        }
                    }
                    if viewModel.hasMultipleServers {
                        Section(L10n.NativeSidebar.switchServer) {
                            ForEach(viewModel.servers, id: \.identifier) { server in
                                Button {
                                    viewModel.open(server: server)
                                } label: {
                                    if server.identifier == viewModel.server.identifier {
                                        Label(server.info.name, systemSymbol: .checkmark)
                                    } else {
                                        Text(server.info.name)
                                    }
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: DesignSystem.Spaces.oneAndHalf) {
                        MacSidebarAvatarView(
                            server: viewModel.server,
                            title: viewModel.profileItem?.title ?? viewModel.server.info.name,
                            user: viewModel.sidebar.user,
                            size: Constants.avatarSize,
                            accentColor: accentColor
                        )
                        .overlay(Circle().strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
                        VStack(alignment: .leading, spacing: DesignSystem.Spaces.micro) {
                            Text(viewModel.profileItem?.title ?? viewModel.server.info.name)
                                .font(.headline)
                                .foregroundStyle(Color.primary)
                                .lineLimit(1)
                            HStack(spacing: DesignSystem.Spaces.half) {
                                Text(viewModel.server.info.name)
                                    .lineLimit(1)
                                if viewModel.hasMultipleServers {
                                    Image(systemSymbol: .chevronUpChevronDown)
                                        .font(.caption2.weight(.semibold))
                                }
                            }
                            .font(.subheadline)
                            .foregroundStyle(Color.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(NativeSidebarRowButtonStyle())
                .accessibilityLabel(viewModel.server.info.name)

                Spacer(minLength: 0)

                Button {
                    viewModel.showAppSettings(using: appSettingsPresenter)
                } label: {
                    Image(systemSymbol: .gearshape)
                        .font(.system(size: Constants.settingsIconSize, weight: .medium))
                        .foregroundStyle(Color.primary)
                        .frame(width: Constants.quickActionHeight, height: Constants.quickActionHeight)
                        .haGlassBackground(in: Circle())
                }
                .buttonStyle(NativeSidebarRowButtonStyle())
                .modify { view in
                    if let transitionNamespace {
                        view.zoomTransitionSource(id: NativeSidebarViewModel.appSettingsTransitionID, in: transitionNamespace)
                    } else {
                        view
                    }
                }
                .accessibilityLabel(L10n.NativeSidebar.appSettings)
            }
            .padding(.horizontal, DesignSystem.Spaces.two)
            .padding(.top, DesignSystem.Spaces.one)

            // Quick actions: the frontend's search, and Assist.
            HStack(spacing: DesignSystem.Spaces.one) {
                Button {
                    viewModel.quickSearch()
                } label: {
                    HStack(spacing: DesignSystem.Spaces.one) {
                        Image(systemSymbol: .magnifyingglass)
                        Text(L10n.NativeSidebar.search)
                        Spacer(minLength: 0)
                    }
                    .font(.body)
                    .foregroundStyle(Color.secondary)
                    .padding(.horizontal, DesignSystem.Spaces.oneAndHalf)
                    .frame(height: Constants.quickActionHeight)
                    .frame(maxWidth: .infinity)
                    .haGlassBackground(in: Capsule())
                }
                .buttonStyle(NativeSidebarRowButtonStyle())

                Button {
                    viewModel.assist()
                } label: {
                    Image(systemSymbol: .waveform)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: Constants.quickActionHeight, height: Constants.quickActionHeight)
                        .haGlassBackground(in: Circle(), tint: accentColor)
                }
                .buttonStyle(NativeSidebarRowButtonStyle())
                .accessibilityLabel(L10n.NativeSidebar.assist)
            }
            .padding(.horizontal, DesignSystem.Spaces.two)
            .padding(.top, DesignSystem.Spaces.two)
            .padding(.bottom, DesignSystem.Spaces.one)

            ScrollView {
                VStack(spacing: DesignSystem.Spaces.micro) {
                    ForEach(viewModel.mainItems) { item in
                        NativeSidebarRow(
                            item: item,
                            isSelected: viewModel.selectedItemId == item.id,
                            accentColor: accentColor
                        ) {
                            viewModel.select(item)
                        }
                        .background {
                            if viewModel.selectedItemId == item.id {
                                RoundedRectangle(cornerRadius: Constants.selectionCornerRadius, style: .continuous)
                                    .fill(accentColor.opacity(0.14))
                                    .matchedGeometryEffect(id: Constants.selectionID, in: selectionNamespace)
                            }
                        }
                        .contextMenu {
                            if viewModel.canHide(item) {
                                Button {
                                    viewModel.hide(item)
                                } label: {
                                    Label(L10n.Mac.Sidebar.hide, systemSymbol: .eyeSlash)
                                }
                            }
                            Button {
                                isShowingEditor = true
                            } label: {
                                Label(L10n.Mac.Sidebar.edit, systemSymbol: .sliderHorizontal3)
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                    }

                    Divider()
                        .padding(.vertical, DesignSystem.Spaces.one)
                        .padding(.horizontal, DesignSystem.Spaces.two)

                    ForEach([viewModel.settingsItem, viewModel.notificationsItem].compactMap { $0 }) { item in
                        NativeSidebarRow(
                            item: item,
                            isSelected: viewModel.selectedItemId == item.id,
                            accentColor: accentColor
                        ) {
                            viewModel.select(item)
                        }
                        .background {
                            if viewModel.selectedItemId == item.id {
                                RoundedRectangle(cornerRadius: Constants.selectionCornerRadius, style: .continuous)
                                    .fill(accentColor.opacity(0.14))
                                    .matchedGeometryEffect(id: Constants.selectionID, in: selectionNamespace)
                            }
                        }
                    }

                    Button {
                        isShowingEditor = true
                    } label: {
                        Label(L10n.Mac.Sidebar.edit, systemSymbol: .sliderHorizontal3)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(Color.secondary)
                            .padding(.horizontal, DesignSystem.Spaces.two)
                            .frame(maxWidth: .infinity, minHeight: Constants.quickActionHeight, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(NativeSidebarRowButtonStyle())
                    .padding(.top, DesignSystem.Spaces.one)
                }
                .padding(.horizontal, DesignSystem.Spaces.one)
                .padding(.bottom, DesignSystem.Spaces.three)
                .animation(DesignSystem.Motion.smooth, value: viewModel.mainItems)
            }
            .scrollIndicators(.hidden)
        }
        .sheet(isPresented: $viewModel.isShowingNotifications) {
            NativeNotificationsView(
                viewModel: NativeNotificationsViewModel(server: viewModel.server),
                onOpenLink: viewModel.openNotificationLink
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShowingEditor) {
            NativeSidebarEditView(viewModel: viewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

#Preview {
    let server = ServerFixture.standard
    let overlayState = WebFrontendOverlayState()
    let viewModel = NativeSidebarViewModel(
        sidebar: MacSidebarViewModel(server: server, overlayState: overlayState),
        overlayState: overlayState
    )
    return ZStack(alignment: .leading) {
        NativeSidebarBackdrop(accentColor: .haPrimary)
            .ignoresSafeArea()
        NativeSidebarView(viewModel: viewModel, accentColor: .haPrimary)
            .frame(width: 320)
    }
}
