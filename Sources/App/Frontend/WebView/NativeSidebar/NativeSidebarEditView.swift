import SFSafeSymbols
import Shared
import SwiftUI

/// Reorder, hide and show panels, saved to the same frontend user data the web sidebar's editor writes.
struct NativeSidebarEditView: View {
    private enum Constants {
        static let iconSize: CGFloat = 22
    }

    @ObservedObject var viewModel: NativeSidebarViewModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(viewModel.mainItems) { item in
                        Label {
                            Text(item.title)
                        } icon: {
                            Image(uiImage: item.icon.image(
                                ofSize: .init(width: Constants.iconSize, height: Constants.iconSize),
                                color: .label
                            ))
                            .renderingMode(.template)
                            .foregroundStyle(Color.haPrimary)
                        }
                        .swipeActions(edge: .trailing) {
                            if viewModel.canHide(item) {
                                Button {
                                    viewModel.hide(item)
                                } label: {
                                    Label(L10n.Mac.Sidebar.hide, systemSymbol: .eyeSlash)
                                }
                                .tint(.orange)
                            }
                        }
                    }
                    .onMove { source, destination in
                        viewModel.move(fromOffsets: source, toOffset: destination)
                    }
                }

                if !viewModel.hiddenItems.isEmpty {
                    Section(L10n.Mac.Sidebar.HiddenSection.header) {
                        ForEach(viewModel.hiddenItems) { item in
                            Button {
                                viewModel.show(item)
                            } label: {
                                HStack {
                                    Label {
                                        Text(item.title)
                                            .foregroundStyle(Color.primary)
                                    } icon: {
                                        Image(uiImage: item.icon.image(
                                            ofSize: .init(width: Constants.iconSize, height: Constants.iconSize),
                                            color: .label
                                        ))
                                        .renderingMode(.template)
                                        .foregroundStyle(Color.secondary)
                                    }
                                    Spacer()
                                    Image(systemSymbol: .plusCircleFill)
                                        .symbolRenderingMode(.multicolor)
                                        .font(.title3)
                                }
                            }
                            .accessibilityLabel("\(L10n.Mac.Sidebar.show) \(item.title)")
                        }
                    }
                }
            }
            .environment(\.editMode, .constant(.active))
            .animation(DesignSystem.Motion.smooth, value: viewModel.hiddenItems)
            .navigationTitle(L10n.Mac.Sidebar.edit)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Mac.Sidebar.done) { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    let server = ServerFixture.standard
    let overlayState = WebFrontendOverlayState()
    return NativeSidebarEditView(viewModel: NativeSidebarViewModel(
        sidebar: MacSidebarViewModel(server: server, overlayState: overlayState),
        overlayState: overlayState
    ))
}
