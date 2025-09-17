//
//  MainTabView.swift
//  Dhikr
//
//  Created by Abdul Jabar Nur on 20/05/2024.
//

import SwiftUI
import UIKit

struct DragGestureActiveKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var isDragGestureActive: Bool {
        get { self[DragGestureActiveKey.self] }
        set { self[DragGestureActiveKey.self] = newValue }
    }
}

struct MainTabView: View {
    @State private var selectedTab = 0
    @EnvironmentObject var audioPlayerService: AudioPlayerService
    @EnvironmentObject var quranAPIService: QuranAPIService
    @StateObject private var themeManager = ThemeManager.shared
    @State private var showingFullScreenPlayer = false
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var lastDragValue: CGFloat = 0
    
    
    // MARK: - Performance Optimizations
    // Cache screen height to avoid repeated calculations
    private let screenHeight: CGFloat = UIScreen.main.bounds.height
    private let maxDragDistance: CGFloat = UIScreen.main.bounds.height * 0.85
    
    // Memoized calculations - only update when dependencies change
    private var transitionProgress: CGFloat {
        if showingFullScreenPlayer {
            // Full screen: drag down (positive values)
            let progress = 1.0 - (dragOffset / maxDragDistance)
            return max(0, min(1, progress))
        } else {
            // Mini player: drag up (negative values)
            let absOffset = abs(dragOffset)
            let progress = absOffset / maxDragDistance
            return max(0, min(1, progress))
        }
    }
    
    // Pre-calculated constants for better performance
    private let minScale: CGFloat = 0.92
    private let scaleRange: CGFloat = 0.08 // 1.0 - 0.92
    private let opacityMultiplier: CGFloat = 5.0
    private let backgroundScaleMultiplier: CGFloat = 0.08
    private let backgroundOpacityMultiplier: CGFloat = 0.4
    
    // Optimized computed properties
    private var playerScale: CGFloat {
        minScale + (scaleRange * transitionProgress)
    }
    
    private var miniPlayerOpacity: Double {
        1.0 - (transitionProgress * opacityMultiplier)
    }
    
    private var fullPlayerOpacity: Double {
        transitionProgress
    }
    
    private var backgroundScale: CGFloat {
        1.0 - (backgroundScaleMultiplier * transitionProgress)
    }
    
    private var backgroundOpacity: Double {
        1.0 - (backgroundOpacityMultiplier * transitionProgress)
    }
    
    // Mini player position - stays anchored at the bottom
    private var miniPlayerOffset: CGFloat {
        // The mini player no longer moves. It just fades out in place.
        return 0
    }
    
    // Full player position - updated to feel like it's expanding
    private var fullPlayerOffset: CGFloat {
        let miniPlayerTop = screenHeight - 49 - 65 // Approximate top of mini player
        
        if showingFullScreenPlayer {
            // Follow finger movement directly when dragging down
            return dragOffset
        } else {
            // Slide up from the mini player's position, not the screen bottom.
            // Use a curve to make the initial expansion feel slower.
            let progress = pow(transitionProgress, 0.6)
            return miniPlayerTop * (1.0 - progress)
        }
    }
    
    // Parallax for the content inside the full screen player
    private var contentParallaxOffset: CGFloat {
        let maxParallax: CGFloat = 30
        // The content moves slower than the container, creating depth.
        // It starts with a downward offset and moves up to 0.
        return maxParallax * (1.0 - transitionProgress)
    }
    
    // Background dimming effect
    private var backgroundDimOpacity: Double {
        let maxDim: Double = 0.3
        return maxDim * Double(transitionProgress)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            // Home tab - always load immediately (no lazy loading)
                HomeView()
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }
                    .tag(0)

            LazyTabContent(selectedTab: selectedTab, targetTab: 1) {
                PrayerTimeView()
            }
                    .tabItem {
                        Label("Prayer", systemImage: "timer")
                    }
                    .tag(1)

            LazyTabContent(selectedTab: selectedTab, targetTab: 2) {
                ReciterDirectoryView()
            }
                    .tabItem {
                        Label("Reciters", systemImage: "person.wave.2.fill")
                    }
                    .tag(2)

            LazyTabContent(selectedTab: selectedTab, targetTab: 3) {
                SearchView()
            }
                    .tabItem {
                Label("Focus", systemImage: "shield.fill")
                    }
                    .tag(3)

            LazyTabContent(selectedTab: selectedTab, targetTab: 4) {
                ProfileView()
            }
                    .tabItem {
                        Label("Profile", systemImage: "person.fill")
                    }
                    .tag(4)
            }
        .ignoresSafeArea(.keyboard)
        .opacity(backgroundOpacity) // Fade background
        .animation(isDragging ? nil : .interpolatingSpring(stiffness: 300, damping: 28), value: showingFullScreenPlayer)
        .disabled(isDragging || showingFullScreenPlayer) // Disable interaction
        // Re-add connected player overlay (mini + full screen)
        .overlay(
            Group {
                if audioPlayerService.currentSurah != nil {
                    playerView()
                }
            }
        )
        .environmentObject(audioPlayerService)
        .environmentObject(quranAPIService)
        .preferredColorScheme(themeManager.currentTheme == .dark ? .dark : nil)
        .onAppear {
            configureTabBarAppearance()
        }
        .onChange(of: themeManager.currentTheme) { _ in
            configureTabBarAppearance()
        }
    }

    private func playerView() -> some View {
        let drag = DragGesture()
            .onChanged { value in
                if !isDragging {
                    isDragging = true
                    lastDragValue = value.translation.height
                }
                
                if showingFullScreenPlayer {
                    // Follow finger directly - only allow downward dragging
                    dragOffset = max(0, value.translation.height)
                } else {
                    // Follow finger directly - only allow upward dragging
                    dragOffset = min(0, value.translation.height)
                }
            }
            .onEnded { value in
                isDragging = false
                
                if showingFullScreenPlayer {
                    handleFullScreenDragEnd(
                        translation: value.translation.height,
                        velocity: value.predictedEndTranslation.height - value.translation.height
                    )
                } else {
                    handleMiniPlayerDragEnd(
                        translation: value.translation.height,
                        velocity: value.predictedEndTranslation.height - value.translation.height
                    )
                }
            }

        // Dynamic player positioning - adapts to device safe areas
        return GeometryReader { geometry in
            let safeAreaBottom = geometry.safeAreaInsets.bottom
            let miniPlayerHeight: CGFloat = 70
            
            let playerOffset: CGFloat = {
                if showingFullScreenPlayer {
                    // Prevent dragging above the top of the screen (full screen position)
                    return max(0, dragOffset)
                } else {
                    let availableHeight = geometry.size.height
                    let screenHeight = UIScreen.main.bounds.height
                    
                    // Detect if keyboard is likely present by comparing available vs screen height
                    let isKeyboardPresent = availableHeight < screenHeight - 100 // 100pt threshold for keyboard detection
                    
                    let miniPlayerPosition: CGFloat
                    if isKeyboardPresent {
                        // Keyboard present: position at bottom of available space (on keyboard)
                        miniPlayerPosition = availableHeight - miniPlayerHeight
                    } else {
                        // No keyboard: position above tab bar with adjustment
                        let tabBarSpace = (safeAreaBottom + 49) - 30 // Safe area + tab bar height, dropped 30pts lower
                        miniPlayerPosition = availableHeight - tabBarSpace - miniPlayerHeight
                    }
                    
                    let calculatedOffset = miniPlayerPosition + dragOffset
                    // Prevent dragging above full screen position (0) when expanding
                    return max(0, calculatedOffset)
                }
            }()
            
            ZStack(alignment: .top) {
                // Full Screen Player
            FullScreenPlayerView {
                    closeFullScreenPlayer()
                }
                .opacity(fullPlayerOpacity)
                
                // Mini Player Bar - connected to the full screen player
                MiniPlayerBar(showingFullScreenPlayer: $showingFullScreenPlayer)
                    .environment(\.isDragGestureActive, isDragging)
                    .onTapGesture {
                        openFullScreenPlayer()
            }
                    .opacity(miniPlayerOpacity)
            }
            .frame(height: geometry.size.height)
            .offset(y: playerOffset)
            .animation(isDragging ? nil : .interpolatingSpring(stiffness: 300, damping: 28), value: playerOffset)
            .gesture(drag)
            .onChange(of: audioPlayerService.currentSurah) { _ in
                withAnimation(.interpolatingSpring(stiffness: 300, damping: 28)) {
                    if !showingFullScreenPlayer {
                        dragOffset = 0
                    }
                }
            }
        }
    }
    
    // Open full screen player - smooth expansion animation
    private func openFullScreenPlayer() {
        guard !isDragging else { return }
        withAnimation(.interpolatingSpring(stiffness: 300, damping: 28)) {
            showingFullScreenPlayer = true
            dragOffset = 0
        }
    }
    
    // Close full screen player - smooth minimizing animation
    private func closeFullScreenPlayer() {
        guard !isDragging else { return }
        withAnimation(.interpolatingSpring(stiffness: 300, damping: 28)) {
            showingFullScreenPlayer = false
            dragOffset = 0
                    }
                }
    
    // Handle mini player drag end - expansion logic
    private func handleMiniPlayerDragEnd(translation: CGFloat, velocity: CGFloat) {
        let threshold = screenHeight * 0.15 // 15% of screen height
        let velocityThreshold: CGFloat = 400 // Responsive velocity threshold
        
        let shouldExpand = abs(translation) > threshold || abs(velocity) > velocityThreshold
        
        if shouldExpand {
            // Expand to full screen with momentum-based animation
            let stiffness = max(250, min(400, 300 + (abs(velocity) / 10)))
            withAnimation(.interpolatingSpring(stiffness: stiffness, damping: 25)) {
                showingFullScreenPlayer = true
                dragOffset = 0
            }
        } else {
            // Snap back to mini player
            withAnimation(.interpolatingSpring(stiffness: 400, damping: 30)) {
                dragOffset = 0
            }
        }
    }
    
    // Handle full screen player drag end - minimizing logic
    private func handleFullScreenDragEnd(translation: CGFloat, velocity: CGFloat) {
        let threshold = screenHeight * 0.15 // 15% of screen height
        let velocityThreshold: CGFloat = 400 // Responsive velocity threshold
        
        let shouldMinimize = translation > threshold || velocity > velocityThreshold
        
        if shouldMinimize {
            // Minimize to mini player with momentum-based animation
            let stiffness = max(250, min(400, 300 + (velocity / 10)))
            withAnimation(.interpolatingSpring(stiffness: stiffness, damping: 25)) {
                showingFullScreenPlayer = false
                dragOffset = 0
            }
        } else {
            // Snap back to full screen
            withAnimation(.interpolatingSpring(stiffness: 400, damping: 30)) {
                dragOffset = 0
            }
        }
    }
    
    // MARK: - Tab Bar Appearance Configuration
    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        
        switch themeManager.currentTheme {
        case .light:
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor.systemBackground
            
        case .dark:
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(Color(hex: "1E3A5F"))
            
        case .liquidGlass:
            // Since UIDesignRequiresCompatibility is enabled globally,
            // we use transparent background which will work with our manual glass effects
            appearance.configureWithTransparentBackground()
            appearance.backgroundColor = UIColor.clear
        }
        
        // Apply the appearance
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

// (Removed compact early unlock banner component)

// Custom View Modifier for transparent full screen cover
struct TransparentFullScreenCover<CoverContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    let coverContent: CoverContent

    func body(content: Content) -> some View {
        ZStack {
            content
            if isPresented {
                coverContent
                    .edgesIgnoringSafeArea(.all)
    }
        }
    }
}

extension View {
    func transparentFullScreenCover<CoverContent: View>(isPresented: Binding<Bool>, @ViewBuilder content: () -> CoverContent) -> some View {
        self.modifier(
            TransparentFullScreenCover(
                isPresented: isPresented,
                coverContent: content()
            )
        )
    }
}

// MARK: - Lazy Tab Loading Component
struct LazyTabContent<Content: View>: View {
    let selectedTab: Int
    let targetTab: Int
    let content: () -> Content
    
    @State private var hasLoaded = false
    
    var body: some View {
        Group {
            if hasLoaded {
                content()
            } else {
                // Show loading placeholder
                VStack {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            }
        }
        .onAppear {
            // Load content when tab becomes visible
            if selectedTab == targetTab {
                hasLoaded = true
            }
        }
        .onChange(of: selectedTab) { newTab in
            // Load content when tab is selected
            if newTab == targetTab && !hasLoaded {
                hasLoaded = true
            }
        }
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
        MainTabView()
                .environmentObject(DhikrService.shared)
            .environmentObject(AudioPlayerService.shared)
                .environmentObject(BluetoothService())
            .environmentObject(QuranAPIService.shared)
                .environmentObject(PrayerTimeViewModel())
                .environmentObject(FavoritesManager.shared)
                .environmentObject(LocationService())
                .previewDisplayName("Main Tab View")
                .onAppear {
                    // Initialize audio player with safe values for preview
                    let audioPlayer = AudioPlayerService.shared
                    audioPlayer.duration = 300 // 5 minutes
                    audioPlayer.currentTime = 0
                    audioPlayer.isPlaying = false
                }
        }
    }
} 