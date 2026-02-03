//
//  AudioPlayerService.swift
//  QariVerse
//
//  Created by Abduljabar Nur on 6/21/25.
//

import Foundation
import AVFoundation
import MediaPlayer
import UIKit
import FirebaseAuth

// MARK: - Audio Player Service
class AudioPlayerService: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var currentSurah: Surah?
    @Published var currentReciter: Reciter?
    @Published var playbackSpeed: Float = 1.0
    @Published var repeatMode: RepeatMode = .off
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isReadyToPlay: Bool = false
    @Published var isShuffleEnabled: Bool = false
    @Published var totalListeningTime: TimeInterval = 0
    @Published var completedSurahNumbers: Set<Int> = []
    
    // Track listening time during playback
    private var lastRecordedTime: TimeInterval = 0
    private var sessionStartTime: TimeInterval = 0
    @Published var isAutoplayEnabled: Bool = true
    @Published var currentArtwork: UIImage?
    @Published var sleepTimeRemaining: TimeInterval?
    @Published var likedItems: Set<LikedItem> = []
    @Published var hasPlayedOnce: Bool = false
    @Published var shouldShowFullScreenPlayer: Bool = false

    // MARK: - Private Properties
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var sleepTimer: Timer?
    private var isAudioSessionActive = false
    private var wasPlayingBeforeInterruption = false
    private var allSurahs: [Surah] = []
    private var currentPlaylist: [Surah] = []
    private var currentSurahIndex: Int = -1
    private var shuffledPlaylistIndices: [Int] = []
    private var defaultArtwork: MPMediaItemArtwork?
    private var currentArtworkImage: UIImage?
    private var isPreloaded = false // Track if audio is just preloaded vs actively playing
    private var preloadedSurah: Surah?
    private var preloadedReciter: Reciter?
    
    // MARK: - UserDefaults Keys
    private let lastPlayedSurahKey = "lastPlayedSurah"
    private let lastPlayedReciterKey = "lastPlayedReciter"
    private let lastPlayedTimeKey = "lastPlayedTime"
    private let likedItemsKey = "likedItems"
    
    // MARK: - Repeat Mode
    enum RepeatMode: String, CaseIterable {
        case off = "Off"
        case one = "One"
        case all = "All"

        var icon: String {
            switch self {
            case .off: return "repeat"
            case .one: return "repeat.1"
            case .all: return "repeat"
            }
        }
    }
    
    // MARK: - Singleton
    static let shared = AudioPlayerService()
    private override init() {
        super.init()

        // Setup audio interruption handling
        setupAudioInterruptionHandling()

        // Load liked items from UserDefaults on initialization
        if let data = UserDefaults.standard.data(forKey: likedItemsKey) {
            do {
                self.likedItems = try JSONDecoder().decode(Set<LikedItem>.self, from: data)
            } catch {
                self.likedItems = []
            }
        } else {
            self.likedItems = []
        }

        // Load listening statistics
        self.totalListeningTime = UserDefaults.standard.double(forKey: "totalListeningTime")
        if let completedArray = UserDefaults.standard.array(forKey: "completedSurahNumbers") as? [Int] {
            self.completedSurahNumbers = Set(completedArray)
        }

        // Load auto-play setting (default to true)
        self.isAutoplayEnabled = UserDefaults.standard.object(forKey: "autoPlayNextSurah") as? Bool ?? true

        // Log all tracking data on app launch
        logAllTrackingData()
    }

    // MARK: - Tracking Data Logging
    private func logAllTrackingData() {

        // Audio Player Tracking Data
        let audioTrackingData: [String: Any] = [
            "totalListeningTime": totalListeningTime,
            "totalListeningTimeFormatted": getTotalListeningTimeString(),
            "completedSurahNumbers": Array(completedSurahNumbers).sorted(),
            "completedSurahCount": completedSurahNumbers.count,
            "likedItemsCount": likedItems.count,
            "likedItems": likedItems.map { ["surahNumber": $0.surahNumber, "reciterIdentifier": $0.reciterIdentifier, "dateAdded": ISO8601DateFormatter().string(from: $0.dateAdded)] },
            "autoPlayEnabled": isAutoplayEnabled
        ]

        if let audioJSON = try? JSONSerialization.data(withJSONObject: audioTrackingData, options: .prettyPrinted),
           let audioJSONString = String(data: audioJSON, encoding: .utf8) {
        }

        // Recent Plays
        let recentPlays = RecentsManager.shared.recentItems.map { item in
            return [
                "surah": "\(item.surah.number). \(item.surah.englishName)",
                "reciter": item.reciter.englishName,
                "playedAt": ISO8601DateFormatter().string(from: item.playedAt)
            ]
        }

        if let recentsJSON = try? JSONSerialization.data(withJSONObject: ["recentPlays": recentPlays], options: .prettyPrinted),
           let recentsJSONString = String(data: recentsJSON, encoding: .utf8) {
        }

        // Favorite Reciters
        let favoriteReciters = FavoritesManager.shared.favoriteReciters.map { item in
            return [
                "identifier": item.identifier,
                "dateAdded": ISO8601DateFormatter().string(from: item.dateAdded)
            ]
        }

        if let favoritesJSON = try? JSONSerialization.data(withJSONObject: ["favoriteReciters": favoriteReciters], options: .prettyPrinted),
           let favoritesJSONString = String(data: favoritesJSON, encoding: .utf8) {
        }

        // Last Played Info
        if let lastPlayed = getLastPlayedInfo() {
            let lastPlayedData: [String: Any] = [
                "surah": "\(lastPlayed.surah.number). \(lastPlayed.surah.englishName)",
                "reciter": lastPlayed.reciter.englishName,
                "time": lastPlayed.time
            ]

            if let lastPlayedJSON = try? JSONSerialization.data(withJSONObject: ["lastPlayed": lastPlayedData], options: .prettyPrinted),
               let lastPlayedJSONString = String(data: lastPlayedJSON, encoding: .utf8) {
            }
        } else {
        }

    }
    
    // MARK: - Activation
    func activate() {
        setupAudioSession()
        setupRemoteTransportControls()
        setupDefaultArtwork()
    }
    
    func deactivate() {
        
        saveLastPlayed()
        // Stop playback
        pause()
        
        // Deactivate audio session
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            isAudioSessionActive = false
        } catch {
        }
        
        // Remove remote command targets
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.nextTrackCommand.removeTarget(nil)
        commandCenter.previousTrackCommand.removeTarget(nil)
        commandCenter.changePlaybackPositionCommand.removeTarget(nil)
        
        // Remove interruption observers
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.routeChangeNotification, object: nil)
        
    }
    
    // MARK: - Setup
    private func setupAudioSession() {
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            // Set category for background audio playback
            try audioSession.setCategory(.playback, mode: .default, options: [.allowAirPlay, .allowBluetooth, .mixWithOthers])
            
            // Activate the session
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            isAudioSessionActive = true
            
            
        } catch {
        }
    }
    
    private func setupAudioInterruptionHandling() {
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
        
    }
    
    @objc private func handleAudioSessionInterruption(notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            wasPlayingBeforeInterruption = isPlaying
            if isPlaying {
                pause()
            }
            
        case .ended:
            
            guard let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt else {
                return
            }
            
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            
            if options.contains(.shouldResume) && wasPlayingBeforeInterruption {
                
                // Small delay to ensure audio session is ready
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.play()
                }
            } else {
            }
            
            wasPlayingBeforeInterruption = false
            
        @unknown default:
            break
        }
    }
    
    @objc private func handleAudioSessionRouteChange(notification: Notification) {
        guard let info = notification.userInfo,
              let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        switch reason {
        case .oldDeviceUnavailable:
            if isPlaying {
                pause()
            }
            
        case .newDeviceAvailable:
            break
        default:
            break
        }
    }
    
    private func setupRemoteTransportControls() {
        
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // Play command
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.play()
            return .success
        }
        
        // Pause command
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        
        // Next track command
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.nextTrack()
            return .success
        }
        
        // Previous track command
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.previousTrack()
            return .success
        }
        
        // Seek command
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self?.seek(to: event.positionTime)
            return .success
        }
        
    }
    
    // MARK: - Artwork Setup
    private func setupDefaultArtwork() {
        
        // Try to load app icon as artwork
        if let appIcon = UIImage(named: "AppIcon") ?? UIImage(systemName: "book.closed") {
            let artwork = MPMediaItemArtwork(boundsSize: appIcon.size) { size in
                return appIcon
            }
            defaultArtwork = artwork
        } else {
            // Fallback to a system icon
            if let systemIcon = UIImage(systemName: "music.note", withConfiguration: UIImage.SymbolConfiguration(pointSize: 200)) {
                let artwork = MPMediaItemArtwork(boundsSize: systemIcon.size) { size in
                    return systemIcon
                }
                defaultArtwork = artwork
            }
        }
    }
    
    private func createArtworkImage() -> UIImage? {
        // Try different approaches to get an appropriate image
        
        // 1. Try to use app icon
        if let appIcon = UIImage(named: "AppIcon") {
            return appIcon
        }
        
        // 2. Try to get the app icon from the bundle
        if let iconName = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any],
           let primaryIcon = iconName["CFBundlePrimaryIcon"] as? [String: Any],
           let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
           let iconFile = iconFiles.last,
           let icon = UIImage(named: iconFile) {
            return icon
        }
        
        // 3. Create a custom Quran-themed image using system symbols
        let config = UIImage.SymbolConfiguration(pointSize: 200, weight: .medium)
        if let bookIcon = UIImage(systemName: "book.closed.fill", withConfiguration: config) {
            // Create a styled version
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 300))
            let styledImage = renderer.image { context in
                // Set background
                UIColor.systemBackground.setFill()
                context.fill(CGRect(x: 0, y: 0, width: 300, height: 300))
                
                // Draw the book icon in the center
                let iconRect = CGRect(x: 50, y: 50, width: 200, height: 200)
                bookIcon.withTintColor(.systemBlue).draw(in: iconRect)
            }
            return styledImage
        }
        
        // 4. Final fallback - simple colored rectangle with text
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 300))
        return renderer.image { context in
            // Background
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 300, height: 300))
            
            // Text
            let text = "الذكر"
            let attributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: UIColor.white,
                .font: UIFont.systemFont(ofSize: 48, weight: .bold)
            ]
            let attributedText = NSAttributedString(string: text, attributes: attributes)
            let textSize = attributedText.size()
            let textRect = CGRect(
                x: (300 - textSize.width) / 2,
                y: (300 - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            attributedText.draw(in: textRect)
        }
    }
    
    // MARK: - Playback Control - Public
    
    /// Loads a specific surah for a specific reciter and starts playback.
    /// This is the primary entry point for starting audio.
    func load(surah: Surah, reciter: Reciter) {
        Task {
            await loadAndPlay(surah: surah, reciter: reciter)
        }
    }
    
    func play() {
        if player?.currentItem != nil {

            guard let player = player else {
                return
            }

            // Ensure audio session is active
            if !isAudioSessionActive {
                setupAudioSession()
            } else {
            }
            player.play()
            isPlaying = true
            hasPlayedOnce = true

            // Track Quran audio played
            AnalyticsService.shared.trackQuranAudioPlayed()

            // Only initialize lastRecordedTime on first play, not on resume
            // This ensures accurate time tracking when resuming from pause
            if lastRecordedTime == 0 {
                lastRecordedTime = currentTime
            } else {
            }

            updateNowPlayingInfo()
        }
    }
    
    func pause() {
        
        player?.pause()
        isPlaying = false
        updateNowPlayingInfo()
        saveLastPlayed()
        
    }
    
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    func seek(to time: TimeInterval, completion: ((Bool) -> Void)? = nil) {
        
        guard let player = player else {
            completion?(false)
            return
        }
        
        let cmTime = CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player.seek(to: cmTime) { [weak self] finished in
            if finished {
                self?.currentTime = time
                self?.updateNowPlayingInfo()
            } else {
            }
            completion?(finished)
        }
    }
    
    func setPlaybackSpeed(_ speed: Float) {
        playbackSpeed = speed
        player?.rate = speed
        updateNowPlayingInfo()
    }
    
    func setRepeatMode(_ mode: RepeatMode) {
        repeatMode = mode
    }
    
    // MARK: - Verse Navigation
    func nextVerse() {
        
        if repeatMode == .all {
            // Restart from beginning
            loadFullSurahAudio(surah: currentSurah!, reciter: currentReciter!)
        } else {
        }
    }
    
    func previousVerse() {
        
    }
    
    // MARK: - Track Management
    private func loadFullSurahAudio(surah: Surah, reciter: Reciter) {
        isLoading = true
        isReadyToPlay = false
        
        Task {
            do {
                // Get full surah audio URL from Quran Foundation API
                let audioURLString = try await QuranAPIService.shared.constructAudioURL(surahNumber: surah.number, reciter: reciter)
                
                guard let url = URL(string: audioURLString) else {
                    await MainActor.run {
                        self.errorMessage = "Invalid audio URL"
                        self.isLoading = false
                    }
                    return
                }
                
                
                // Create and configure player
                let playerItem = AVPlayerItem(url: url)
                let newPlayer = AVPlayer(playerItem: playerItem)
                
                // Add observer for player item status
                playerItem.addObserver(self, forKeyPath: "status", options: [.new, .old], context: nil)
                
                // Add observer for playback buffer
                playerItem.addObserver(self, forKeyPath: "loadedTimeRanges", options: [.new], context: nil)
                
                // Add observer for playback end
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(playerDidFinishPlaying(note:)),
                    name: .AVPlayerItemDidPlayToEndTime,
                    object: playerItem
                )
                
                await MainActor.run {
                    self.player = newPlayer
                    self.setupTimeObserver()
                    self.setupRemoteTransportControls()
                    self.isLoading = false
                    self.isReadyToPlay = true
                }
                
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load audio: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    private var lastSaveTime: TimeInterval = 0

    private func setupTimeObserver() {
        // Use main queue to ensure thread safety with @Published properties
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))

        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }

            let newTime = time.seconds

            // Track listening time during playback (already on main queue)
            if self.isPlaying {
                let currentPlaybackTime = newTime
                if self.lastRecordedTime > 0 {
                    let timeDifference = currentPlaybackTime - self.lastRecordedTime
                    // Only add time if it's a reasonable increment (0.3 to 1.0 seconds)
                    if timeDifference > 0.3 && timeDifference < 1.0 {
                        self.addListeningTime(timeDifference)
                    }
                }
                self.lastRecordedTime = currentPlaybackTime

                // Periodic save every 30 seconds (for crash/force-quit protection)
                if newTime - self.lastSaveTime >= 30 {
                    self.saveLastPlayed()
                    self.lastSaveTime = newTime
                }
            }

            // Throttle UI updates - only update if time changed significantly
            let timeDiff = abs(newTime - self.currentTime)
            if timeDiff >= 0.45 { // Update roughly every 0.5 seconds
                self.currentTime = newTime
                self.updatePlaybackTime()
            }
        }
    }
    
    // Lightweight method to update only time-sensitive info
    private func updatePlaybackTime() {
        guard MPNowPlayingInfoCenter.default().nowPlayingInfo != nil else { return }
        
        var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? playbackSpeed : 0.0
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    @objc private func playerDidFinishPlaying(note: NSNotification) {
        
        if let surah = currentSurah {
            markSurahCompleted(surah)
        }
        if duration > 0 {
            addListeningTime(duration)
        }
        
        // Priority 1: Repeat a single track
        if repeatMode == .one {
            if let surah = currentSurah, let reciter = currentReciter {
                loadFullSurahAudio(surah: surah, reciter: reciter)
            }
            return
        }
        
        // Priority 2: Autoplay or Repeat All
        if isAutoplayEnabled || repeatMode == .all {
            nextTrack()
        } else {
            // Default: Stop playback
            pause()
        }
    }
    
    func nextTrack() {
        guard !currentPlaylist.isEmpty else {
            return
        }
        
        var nextIndex = -1
        
        if isShuffleEnabled {
            // Find the current index in the shuffled list and get the next one
            if let currentIndexInShuffledList = shuffledPlaylistIndices.firstIndex(of: currentSurahIndex) {
                let nextShuffledIndex = currentIndexInShuffledList + 1
                if nextShuffledIndex < shuffledPlaylistIndices.count {
                    nextIndex = shuffledPlaylistIndices[nextShuffledIndex]
                } else if repeatMode == .all {
                    // Re-shuffle and start from the beginning of the new shuffled list
                    shuffledPlaylistIndices.shuffle()
                    nextIndex = shuffledPlaylistIndices.first ?? 0
                }
            } else {
                // If something went wrong, just pick a new random one
                shuffledPlaylistIndices.shuffle()
                nextIndex = shuffledPlaylistIndices.first ?? 0
            }
        } else {
            // Sequential playback
            let potentialNextIndex = currentSurahIndex + 1
            if potentialNextIndex < currentPlaylist.count {
                nextIndex = potentialNextIndex
            } else if repeatMode == .all {
                nextIndex = 0 // Loop back to the beginning
            }
        }
        
        if nextIndex != -1 {
            let nextSurah = currentPlaylist[nextIndex]
            self.currentSurahIndex = nextIndex
            load(surah: nextSurah, reciter: self.currentReciter!)
        } else {
            pause() // Or handle as desired
        }
    }
    
    func previousTrack() {
        guard !currentPlaylist.isEmpty, let currentReciter = currentReciter else {
            return
        }
        
        var prevIndex = -1

        if isShuffleEnabled {
            // Find the current index in the shuffled list and get the previous one
            if let currentIndexInShuffledList = shuffledPlaylistIndices.firstIndex(of: currentSurahIndex) {
                let prevShuffledIndex = currentIndexInShuffledList - 1
                if prevShuffledIndex >= 0 {
                    prevIndex = shuffledPlaylistIndices[prevShuffledIndex]
                }
                // Don't loop back on previous in shuffle mode
            }
        } else {
            // Sequential playback
            let potentialPrevIndex = currentSurahIndex - 1
            if potentialPrevIndex >= 0 {
                prevIndex = potentialPrevIndex
            }
        }

        if prevIndex != -1 {
            let prevSurah = currentPlaylist[prevIndex]
            self.currentSurahIndex = prevIndex
            load(surah: prevSurah, reciter: currentReciter)
        } else {
            // Seek to the beginning of the current track instead of changing tracks
            seek(to: 0)
        }
    }
    
    // MARK: - KVO
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == #keyPath(AVPlayerItem.status) {
            DispatchQueue.main.async { [weak self] in
                self?.handlePlayerItemStatus()
            }
        } else if keyPath == "loadedTimeRanges" {
            DispatchQueue.main.async { [weak self] in
                self?.handleLoadedTimeRanges()
            }
        }
    }
    
    private func handlePlayerItemStatus() {
        guard let playerItem = player?.currentItem else { return }
        
        
        switch playerItem.status {
        case .readyToPlay:
            isLoading = false
            duration = playerItem.duration.seconds
            
            // Update Now Playing info with duration
            updateNowPlayingInfo()
            
            // Automatically start playing
            DispatchQueue.main.async { [weak self] in
                self?.play()
            }
            
        case .failed:
            isLoading = false
            if let error = playerItem.error {
                errorMessage = error.localizedDescription
            } else {
                errorMessage = "Failed to load audio"
            }
            
        case .unknown:
            break
            
        @unknown default:
            break
        }
    }
    
    private func handleLoadedTimeRanges() {
        guard let playerItem = player?.currentItem else { return }
        
        let ranges = playerItem.loadedTimeRanges
        if let range = ranges.first {
            let duration = CMTimeGetSeconds(range.timeRangeValue.duration)
        }
    }
    
    // MARK: - Now Playing Info
    private func updateNowPlayingInfo() {
        guard let surah = currentSurah, let reciter = currentReciter else { 
            return 
        }
        
        var nowPlayingInfo = [String: Any]()
        
        nowPlayingInfo[MPMediaItemPropertyTitle] = "\(surah.englishName) - \(surah.englishNameTranslation)"
        nowPlayingInfo[MPMediaItemPropertyArtist] = reciter.englishName
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = "The Holy Quran"
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? playbackSpeed : 0.0
        nowPlayingInfo[MPNowPlayingInfoPropertyDefaultPlaybackRate] = 1.0
        
        // Set dynamic artwork for the current surah
        if let image = currentArtwork {
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
        } else if let image = createArtworkImage() {
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
        } else if let artwork = defaultArtwork {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        
    }
    
    // MARK: - Clear Current Audio
    private func clearCurrentAudio() {
        isReadyToPlay = false

        // Stop current playback
        if let player = player {
            player.pause()
        }

        // Clear current track info
        currentSurah = nil
        currentReciter = nil
        currentArtwork = nil
        isPlaying = false
        currentTime = 0
        duration = 0

        // Reset listening time tracking for new track
        lastRecordedTime = 0

        // Clear Now Playing info
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil

    }
    
    // MARK: - Cleanup
    deinit {
        if let timeObserver = timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
        player?.currentItem?.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.status))
        player?.currentItem?.removeObserver(self, forKeyPath: "loadedTimeRanges")
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.routeChangeNotification, object: nil)
        deactivate()
    }
    
    // MARK: - Additional Controls
    func toggleRepeatMode() {
        let allModes = RepeatMode.allCases
        if let currentIndex = allModes.firstIndex(of: repeatMode), currentIndex + 1 < allModes.count {
            repeatMode = allModes[currentIndex + 1]
        } else {
            repeatMode = allModes[0]
        }
    }
    
    // MARK: - Load All Surahs (for navigation)
    func loadAllSurahs(_ surahs: [Surah]) {
        allSurahs = surahs.sorted { $0.number < $1.number }
    }
    
    // MARK: - Shuffle Functionality
    func toggleShuffle() {
        isShuffleEnabled.toggle()
        
        if isShuffleEnabled {
            // When enabling shuffle, create a shuffled list of indices from the current playlist
            shuffledPlaylistIndices = Array(0..<currentPlaylist.count)
            shuffledPlaylistIndices.shuffle()
            
            // Ensure the current playing track is the first in the shuffled sequence
            if let index = shuffledPlaylistIndices.firstIndex(of: currentSurahIndex) {
                shuffledPlaylistIndices.swapAt(0, index)
        }
        }
        // When disabling, we don't need to do anything, it will revert to sequential playback.
    }
    
    // MARK: - Preload Last Played
    func preloadLastPlayed() {
        
        guard let lastPlayedInfo = getLastPlayedInfo() else {
            return
        }
        
        
        Task {
            await preloadAudio(surah: lastPlayedInfo.surah, reciter: lastPlayedInfo.reciter, startTime: lastPlayedInfo.time)
        }
    }
    
    // MARK: - Continue Last Played
    func continueLastPlayed() -> Bool {
        
        guard let lastPlayedInfo = getLastPlayedInfo() else {
            return false
        }
        
        // Check if audio is already preloaded
        if let surah = preloadedSurah, let reciter = preloadedReciter,
           surah.id == lastPlayedInfo.surah.id && reciter.id == lastPlayedInfo.reciter.id,
           isPreloaded && isReadyToPlay {

            // Now expose the preloaded audio to the UI
            currentSurah = surah
            currentReciter = reciter
            isPreloaded = false
            // Reset time tracking for this playback session
            lastRecordedTime = 0

            // Log to recents manager now that user is actually playing
            RecentsManager.shared.addTrack(surah: surah, reciter: reciter)

            // Fetch artwork for the surah
            Task {
                await fetchSurahCoverArtwork(for: surah)
            }

            seek(to: lastPlayedInfo.time) { [weak self] completed in
                if completed {
                    self?.play()
                } else {
                    self?.play()
                }
            }
            return true
        }
        
        
        Task {
            await loadAndPlay(surah: lastPlayedInfo.surah, reciter: lastPlayedInfo.reciter, startTime: lastPlayedInfo.time)
        }
        
        return true
    }
    
    // MARK: - Save Last Played
    func saveLastPlayed() {
        guard let surah = currentSurah, let reciter = currentReciter else { return }
        guard currentTime > 1.0 else { return }

        do {
            let surahData = try JSONEncoder().encode(surah)
            let reciterData = try JSONEncoder().encode(reciter)

            UserDefaults.standard.set(surahData, forKey: lastPlayedSurahKey)
            UserDefaults.standard.set(reciterData, forKey: lastPlayedReciterKey)
            UserDefaults.standard.set(currentTime, forKey: lastPlayedTimeKey)
            UserDefaults.standard.synchronize()
        } catch { }
    }

    /// Force save with specific surah/reciter (used when loading new audio)
    func saveLastPlayedTrack(surah: Surah, reciter: Reciter, time: TimeInterval = 0) {
        do {
            let surahData = try JSONEncoder().encode(surah)
            let reciterData = try JSONEncoder().encode(reciter)

            UserDefaults.standard.set(surahData, forKey: lastPlayedSurahKey)
            UserDefaults.standard.set(reciterData, forKey: lastPlayedReciterKey)
            UserDefaults.standard.set(time, forKey: lastPlayedTimeKey)
            UserDefaults.standard.synchronize()
        } catch { }
    }
    
    // MARK: - Sleep Timer
    func setSleepTimer(minutes: Double) {
        cancelSleepTimer() // Invalidate any existing timer
        let timeInSeconds = minutes * 60
        self.sleepTimeRemaining = timeInSeconds
        
        
        self.sleepTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            if let remaining = self.sleepTimeRemaining {
                if remaining > 1 {
                    self.sleepTimeRemaining = remaining - 1
                } else {
                    self.pause()
                    self.cancelSleepTimer()
                }
            }
        }
    }

    func cancelSleepTimer() {
        sleepTimer?.invalidate()
        sleepTimer = nil
        sleepTimeRemaining = nil
    }
    
    // MARK: - Get Last Played Info
    func getLastPlayedInfo() -> (surah: Surah, reciter: Reciter, time: TimeInterval)? {
        guard let lastSurahData = UserDefaults.standard.data(forKey: lastPlayedSurahKey),
              let lastReciterData = UserDefaults.standard.data(forKey: lastPlayedReciterKey),
              let lastSurah = try? JSONDecoder().decode(Surah.self, from: lastSurahData),
              let lastReciter = try? JSONDecoder().decode(Reciter.self, from: lastReciterData) else {
            return nil
        }

        let lastTime = UserDefaults.standard.double(forKey: lastPlayedTimeKey)
        return (lastSurah, lastReciter, lastTime)
    }
    
    // MARK: - Listening Stats
    func markSurahCompleted(_ surah: Surah) {
        let wasNew = !completedSurahNumbers.contains(surah.number)
        completedSurahNumbers.insert(surah.number)

        // Persist the completed surahs
        let completedArray = Array(completedSurahNumbers)
        UserDefaults.standard.set(completedArray, forKey: "completedSurahNumbers")

        // Log the update
        if wasNew {
            let data: [String: Any] = [
                "surah": "\(surah.number). \(surah.englishName)",
                "totalCompleted": completedSurahNumbers.count,
                "completedList": completedArray.sorted()
            ]
            if let json = try? JSONSerialization.data(withJSONObject: data, options: .prettyPrinted),
               let jsonString = String(data: json, encoding: .utf8) {
            }
        }
    }

    func addListeningTime(_ seconds: TimeInterval) {
        totalListeningTime += seconds
        // Persist the total listening time
        UserDefaults.standard.set(totalListeningTime, forKey: "totalListeningTime")

        // Log the update (throttled - only log every 10 seconds to avoid spam)
        if Int(totalListeningTime) % 10 == 0 {
            let data: [String: Any] = [
                "totalSeconds": totalListeningTime,
                "formatted": getTotalListeningTimeString(),
                "incrementSeconds": seconds
            ]
            if let json = try? JSONSerialization.data(withJSONObject: data, options: .prettyPrinted),
               let jsonString = String(data: json, encoding: .utf8) {
            }
        }
    }
    
    func getTotalListeningTimeString() -> String {
        if totalListeningTime <= 0 {
            return "0s"
        }
        
        let hours = Int(totalListeningTime) / 3600
        let minutes = (Int(totalListeningTime) % 3600) / 60
        let seconds = Int(totalListeningTime) % 60
        
        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
    
    func getCompletedSurahCount() -> Int {
        completedSurahNumbers.count
    }
    
    func getProgress() -> (completed: Int, total: Int) {
        return (completedSurahNumbers.count, allSurahs.count)
    }
    
    // MARK: - Artwork Update
    func updateArtwork(with newImage: UIImage) {
        self.currentArtwork = newImage
        updateNowPlayingInfo()
    }

    private func fetchSurahCoverArtwork(for surah: Surah) async {
        // Check if user can access premium covers (premium OR authenticated)
        let isPremium = await MainActor.run { SubscriptionService.shared.hasPremiumAccess }
        let isAuthenticated = Auth.auth().currentUser != nil

        guard isPremium || isAuthenticated else {
            await MainActor.run {
                self.currentArtwork = nil
            }
            return
        }

        // Fetch from Firebase Storage (SurahImageService handles anonymous auth if needed)
        if let image = await SurahImageService.shared.fetchSurahCover(for: surah.number) {
            await MainActor.run {
                self.currentArtwork = image
            }
        } else {
            await MainActor.run {
                self.currentArtwork = nil
            }
        }
    }
    
    private func loadAndPlay(surah: Surah, reciter: Reciter, startTime: TimeInterval? = nil) async {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
            self.isReadyToPlay = false
        }
        
        // If the reciter has changed, we need to build a new playlist.
        if reciter.id != self.currentReciter?.id {
            await buildPlaylist(for: reciter)
        }
        
        // Now that the playlist is built, find the index for the requested surah.
        if let index = currentPlaylist.firstIndex(where: { $0.id == surah.id }) {
             await MainActor.run {
                self.currentSurahIndex = index
            }
        } else {
             await MainActor.run {
                self.currentSurahIndex = 0
            }
        }

        // Set the current items on the main thread
        await MainActor.run {
            self.currentSurah = surah
            self.currentReciter = reciter
            // Clear preloaded state since we're now actively playing
            self.isPreloaded = false
            self.preloadedSurah = nil
            self.preloadedReciter = nil
            // Reset time tracking for new track
            self.lastRecordedTime = 0
        }
        
        // Log the track to the recents manager
        RecentsManager.shared.addTrack(surah: surah, reciter: reciter)

        // Save immediately so "Continue Listening" works even if app is killed
        saveLastPlayedTrack(surah: surah, reciter: reciter, time: startTime ?? 0)

        // Fetch surah cover image (only for authenticated users)
        await fetchSurahCoverArtwork(for: surah)

        do {
            let audioURLString = try await QuranAPIService.shared.constructAudioURL(surahNumber: surah.number, reciter: reciter)
            guard let audioURL = URL(string: audioURLString) else {
                throw QuranAPIError.invalidURL
            }
            
            
            let playerItem = AVPlayerItem(url: audioURL)
            
            // Add observer for playback end
            NotificationCenter.default.addObserver(self,
                                               selector: #selector(playerDidFinishPlaying(note:)),
                                               name: .AVPlayerItemDidPlayToEndTime,
                                               object: playerItem)
            
            // Observe when the item is ready to play
            let anObserver = playerItem.observe(\.status, options: [.new, .initial]) { [weak self] item, _ in
                guard let self = self else { return }
                if item.status == .readyToPlay {
                    self.isReadyToPlay = true
                    self.duration = item.duration.seconds
                    
                    if let time = startTime {
                        self.seek(to: time) { [weak self] completed in
                            if completed {
                                self?.play()
                            } else {
                                self?.play()
                            }
                    }
                    } else {
                        self.play() // Start playing immediately if no seek needed
                    }
                    
                } else if item.status == .failed {
                    self.errorMessage = "Failed to load audio."
                }
            }

            await MainActor.run {
                if self.player == nil {
                    self.player = AVPlayer()
                    self.setupTimeObserver()
                }
                self.player?.replaceCurrentItem(with: playerItem)
                self.player?.rate = self.playbackSpeed
                
                // Keep the observer reference
                // Note: In a real app, you would need a more robust way to manage this observer's lifecycle.
                // For this service, we can associate it with the player.
                // A better approach would be a dictionary mapping items to observers.
                // A better approach would be a dictionary mapping items to observers.
                objc_setAssociatedObject(self.player as Any, "playerItemObserver", anObserver, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

                self.updateNowPlayingInfo()
            }
            
        } catch {
            let errorDescription = "Error loading audio: \(error.localizedDescription)"
            await MainActor.run {
                self.errorMessage = errorDescription
            }
        }
        
        await MainActor.run {
            self.isLoading = false
        }
    }
    
    // MARK: - Preload Audio (without playing)
    private func preloadAudio(surah: Surah, reciter: Reciter, startTime: TimeInterval? = nil) async {
        
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
            self.isReadyToPlay = false
        }
        
        // If the reciter has changed, we need to build a new playlist.
        if reciter.id != self.currentReciter?.id {
            await buildPlaylist(for: reciter)
        }
        
        // Now that the playlist is built, find the index for the requested surah.
        if let index = currentPlaylist.firstIndex(where: { $0.id == surah.id }) {
             await MainActor.run {
                self.currentSurahIndex = index
            }
        } else {
             await MainActor.run {
                self.currentSurahIndex = 0
                         }
        }

        // Store preloaded items privately (don't expose to UI yet)
        await MainActor.run {
            self.preloadedSurah = surah
            self.preloadedReciter = reciter
            self.isPreloaded = true
        }

        // Don't log to recents manager yet - only when user actually plays

        // Fetch surah cover image (only for authenticated users) during preload
        await fetchSurahCoverArtwork(for: surah)

        do {
            let audioURLString = try await QuranAPIService.shared.constructAudioURL(surahNumber: surah.number, reciter: reciter)
            guard let audioURL = URL(string: audioURLString) else {
                throw QuranAPIError.invalidURL
            }
            
            
            let playerItem = AVPlayerItem(url: audioURL)
            
            // Add observer for playback end
            NotificationCenter.default.addObserver(self,
                                               selector: #selector(playerDidFinishPlaying(note:)),
                                               name: .AVPlayerItemDidPlayToEndTime,
                                               object: playerItem)
            
            // Observe when the item is ready to play (but don't start playing)
            let anObserver = playerItem.observe(\.status, options: [.new, .initial]) { [weak self] item, _ in
                guard let self = self else { return }
                if item.status == .readyToPlay {
                    self.isReadyToPlay = true
                    self.duration = item.duration.seconds
                    
                    if let time = startTime {
                        self.seek(to: time) { completed in
                            if completed {
                            } else {
                            }
                        }
                    }
                    
                } else if item.status == .failed {
                    self.errorMessage = "Failed to preload audio."
                }
            }

            await MainActor.run {
                if self.player == nil {
                    self.player = AVPlayer()
                    self.setupTimeObserver()
                }
                self.player?.replaceCurrentItem(with: playerItem)
                // Don't set the rate or play - just preload
                
                // Keep the observer reference
                objc_setAssociatedObject(self.player as Any, "playerItemObserver", anObserver, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

                // Don't update now playing info for preloaded audio - no current track to show
            }
            
        } catch {
            let errorDescription = "Error preloading audio: \(error.localizedDescription)"
            await MainActor.run {
                self.errorMessage = errorDescription
            }
        }
        
        await MainActor.run {
            self.isLoading = false
        }
    }
    
    // MARK: - Playlist Management
    private func buildPlaylist(for reciter: Reciter) async {

        // Fetch all 114 surahs to serve as the playlist
        guard let allSurahs = try? await QuranAPIService.shared.fetchSurahs() else {
            await MainActor.run {
                self.currentPlaylist = []
            }
            return
        }


        await MainActor.run {
            self.currentPlaylist = allSurahs

            // If shuffle is on, we need to regenerate the shuffled indices for the new playlist.
            if self.isShuffleEnabled {
                self.shuffledPlaylistIndices = Array(0..<self.currentPlaylist.count)
                self.shuffledPlaylistIndices.shuffle()
            }
        }
    }
    
    // MARK: - Liked Items Management
    
    func isLiked(surahNumber: Int, reciterIdentifier: String) -> Bool {
        let item = LikedItem(surahNumber: surahNumber, reciterIdentifier: reciterIdentifier)
        return likedItems.contains(item)
    }
    
    func toggleLike(surahNumber: Int, reciterIdentifier: String) {
        let item = LikedItem(surahNumber: surahNumber, reciterIdentifier: reciterIdentifier)
        
        if likedItems.contains(item) {
            likedItems.remove(item)
        } else {
            likedItems.insert(item)
        }
        
        saveLikedItems()
    }
    
    private func saveLikedItems() {
        do {
            let data = try JSONEncoder().encode(likedItems)
            UserDefaults.standard.set(data, forKey: likedItemsKey)

            // Log the saved data
            let likedData = likedItems.map { item in
                return [
                    "surahNumber": item.surahNumber,
                    "reciterIdentifier": item.reciterIdentifier,
                    "dateAdded": ISO8601DateFormatter().string(from: item.dateAdded)
                ]
            }

            if let json = try? JSONSerialization.data(withJSONObject: ["likedItems": likedData, "count": likedItems.count], options: .prettyPrinted),
               let jsonString = String(data: json, encoding: .utf8) {
            }
        } catch {
        }
    }
} 