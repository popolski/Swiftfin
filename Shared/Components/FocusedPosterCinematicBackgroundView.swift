//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

#if os(tvOS)
import Defaults
import Nuke
import NukeUI
import SwiftUI

/// Full-screen ambient backdrop behind the tabs.
///
/// A small backdrop is blurred once by Nuke and cached, then scaled up.
/// The previous live `UIVisualEffectView` re-blurred the full screen every frame.
struct FocusedPosterCinematicBackgroundView: View {

    @Default(.Customization.Library.cinematicBackground)
    private var isCinematicBackgroundEnabled

    @FocusedValue(\.focusedPoster)
    private var focusedPoster

    @ContentBuilder
    var body: some View {
        if isCinematicBackgroundEnabled {
            FadeContentTransitionView(
                item: focusedPoster,
                duration: 0.6,
                debounce: 0.4
            ) { item in
                let url = item?.imageSources(
                    for: .landscape,
                    environment: .init(maxWidth: 240, quality: 60, viewContext: .isBackdrop)
                ).first?.url

                LazyImage(
                    request: url.map { ImageRequest(url: $0, processors: [ImageProcessors.GaussianBlur(radius: 6)]) }
                ) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    }
                }
            }
            .overlay(Color.black.opacity(0.55))
            .ignoresSafeArea()
        }
    }
}
#endif
