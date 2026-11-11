//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Defaults
import FactoryKit
import JellyfinAPI
import SwiftUI
@_spi(Advanced) import SwiftUIIntrospect

/// Loads the user's libraries on tvOS so each one gets its own sidebar entry.
struct MainTabView: View {

    #if os(tvOS)
    @Injected(\.currentUserSession)
    private var userSession

    @State
    private var userViews: [BaseItemDto]?

    private func loadUserViews() async -> [BaseItemDto] {
        guard let userSession else { return [] }

        let parameters = Paths.GetUserViewsParameters(userID: userSession.user.id)
        let response = try? await userSession.send(Paths.getUserViews(parameters: parameters))

        return (response?.value.items ?? []).filter {
            CollectionType.supportedCases.contains($0.collectionType ?? .folders)
        }
    }
    #endif

    @ContentBuilder
    var body: some View {
        #if os(tvOS)
        if let userViews {
            MainTabContentView(userViews: userViews)
        } else {
            ProgressView()
                .task {
                    userViews = await loadUserViews()
                }
        }
        #else
        MainTabContentView(userViews: [])
        #endif
    }
}

// TODO: fix weird tvOS icon rendering
private struct MainTabContentView: View {

    #if os(tvOS)
    @Default(.Customization.tabBarPlacement)
    private var tabBarPlacement
    #endif

    @InjectedObject(\.userSessionManager)
    private var userSessionManager

    @StateObject
    private var tabCoordinator: TabCoordinator

    init(userViews: [BaseItemDto]) {
        _tabCoordinator = StateObject(wrappedValue: Self.defaultTabCoordinator(userViews: userViews))
    }

    private static func defaultTabCoordinator(userViews: [BaseItemDto]) -> TabCoordinator {
        #if os(iOS)
        TabCoordinator {
            TabItem.contentGroup(provider: DefaultContentGroupProvider())
            TabItem.search
            TabItem.media
        }
        #else
        TabCoordinator {
            TabItem.contentGroup(provider: DefaultContentGroupProvider())
            TabItem.search

            if userViews.isEmpty {
                TabItem.library(
                    title: L10n.tvShowsCapitalized,
                    systemName: "tv",
                    filters: .init(itemTypes: [.series])
                )

                TabItem.library(
                    title: L10n.movies,
                    systemName: "film",
                    filters: .init(itemTypes: [.movie])
                )

                TabItem.media
            } else {
                userViews.map { TabItem.userView($0) }
            }

            TabItem.settings
        }
        #endif
    }

    private func routePendingDeepLink(_ deepLink: DeepLink?) {
        guard let deepLink else { return }

        Task { @MainActor in
            let route = deepLink.route()
            await tabCoordinator.route(to: route)
        }
    }

    @ContentBuilder
    private func tabRoot(_ tab: TabCoordinator.TabData) -> some View {
        NavigationInjectionView(coordinator: tab.coordinator) {
            tab.item
                .content
                .withViewContext(.isTabRoot)
                #if os(iOS)
                .if(tabCoordinator.tabs.first?.item.id == tab.item.id) { view in
                    view.topBarTrailing {
                        FirstTabSettingsBarButton()
                    }
                }
                #endif
        }
        .environmentObject(tabCoordinator)
        .environment(\.tabItemSelected, tab.publisher)
    }

    @ContentBuilder
    private func tabView() -> some View {
        TabView(selection: $tabCoordinator.selectedTabID) {
            ForEach(tabCoordinator.tabs, id: \.item.id) { tab in
                Tab(
                    value: tab.item.id,
                    role: tab.item.id == TabItem.search.id ? .search : nil
                ) {
                    #if os(tvOS)
                    GeometryReader { _ in
                        tabRoot(tab)
                    }
                    .trackingFrame(for: .tabView)
                    #else
                    tabRoot(tab)
                    #endif
                } label: {
                    Label(
                        tab.item.displayTitle,
                        systemImage: tab.item.systemImage
                    )
                    .symbolRenderingMode(.monochrome)
                }
            }
        }
    }

    @ContentBuilder
    private func tabContent() -> some View {
        #if os(tvOS)
        switch tabBarPlacement {
        case .sidebar:
            tabView()
                .tabViewStyle(.sidebarAdaptable)

        case .tabBar:
            tabView()
                .tabViewStyle(.tabBarOnly)
        }
        #else
        tabView()
            .tabViewStyle(.sidebarAdaptable)
        #endif
    }

    @ContentBuilder
    var body: some View {
        tabContent()
            .onChange(of: userSessionManager.pendingDeepLink) {
                routePendingDeepLink(userSessionManager.consumePendingDeepLink())
            }
            .onReceive(userSessionManager.routePublisher) { route in
                Task { @MainActor in
                    await tabCoordinator.route(to: route)
                }
            }
            #if os(tvOS)
            .background(alignment: .top) {
                FocusedPosterCinematicBackgroundView()
            }
            #endif
    }
}

#if os(iOS)
private struct FirstTabSettingsBarButton: View {

    @Injected(\.currentUserSession)
    private var userSession

    @Router
    private var router

    @ContentBuilder
    var body: some View {
        if router.isRootOfPath,
           let userSession {
            SettingsBarButton(userSession: userSession) {
                router.route(to: .settings)
            }
        }
    }
}
#endif
