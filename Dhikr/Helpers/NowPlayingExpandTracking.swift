//
//  NowPlayingExpandTracking.swift
//  Dhikr
//
//  Adapted from AppleMusicStylePlayer by Alexey Vorobyov
//

import SwiftUI

struct NowPlayingExpandProgressPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = .zero
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct NowPlayingExpandProgressEnvironmentKey: EnvironmentKey {
    static let defaultValue: Double = .zero
}

extension EnvironmentValues {
    var nowPlayingExpandProgress: CGFloat {
        get { self[NowPlayingExpandProgressEnvironmentKey.self] }
        set { self[NowPlayingExpandProgressEnvironmentKey.self] = newValue }
    }
}
