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
        print("🎵 [AudioPlayerService] Initialized")
        
        // Setup audio interruption handling
        setupAudioInterruptionHandling()

        // Load liked items from UserDefaults on initialization
        if let data = UserDefaults.standard.data(forKey: likedItemsKey) {
            do {
                self.likedItems = try JSONDecoder().decode(Set<LikedItem>.self, from: data)
                print("🎵 [AudioPlayerService] Loaded \(likedItems.count) liked items.")
            } catch {
                print("❌ [AudioPlayerService] Failed to decode liked items on init: \(error)")
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
        print("🎵 [AudioPlayerService] Loaded listening stats: \(Int(totalListeningTime))s total, \(completedSurahNumbers.count) completed surahs")
    }
    
    // MARK: - Activation
    func activate() {
        print("🎵 [AudioPlayerService] Activating audio service...")
        setupAudioSession()
        setupRemoteTransportControls()
        setupDefaultArtwork()
        print("🎵 [AudioPlayerService] Audio service activated")
    }
    
    func deactivate() {
        print("🎵 [AudioPlayerService] Deactivating audio service...")
        
        saveLastPlayed()
        // Stop playback
        pause()
        
        // Deactivate audio session
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            isAudioSessionActive = false
            print("🎵 [AudioPlayerService] Audio session deactivated")
        } catch {
            print("❌ [AudioPlayerService] Failed to deactivate audio session: \(error)")
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
        
        print("🎵 [AudioPlayerService] Audio service deactivated")
    }
    
    // MARK: - Setup
    private func setupAudioSession() {
        print("🎵 [AudioPlayerService] Setting up audio session...")
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            // Set category for background audio playback
            try audioSession.setCategory(.playback, mode: .default, options: [.allowAirPlay, .allowBluetooth, .mixWithOthers])
            
            // Activate the session
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            isAudioSessionActive = true
            
            print("✅ [AudioPlayerService] Audio session setup successful")
            print("   - Category: \(audioSession.category)")
            print("   - Mode: \(audioSession.mode)")
            print("   - Sample Rate: \(audioSession.sampleRate)")
            print("   - I/O Buffer Duration: \(audioSession.ioBufferDuration)")
            print("   - Background Audio: Enabled")
            
        } catch {
            print("❌ [AudioPlayerService] Failed to setup audio session: \(error)")
            print("❌ [AudioPlayerService] Error details: \(error.localizedDescription)")
        }
    }
    
    private func setupAudioInterruptionHandling() {
        print("🎵 [AudioPlayerService] Setting up audio interruption handling...")
        
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
        
        print("✅ [AudioPlayerService] Audio interruption handling setup complete")
    }
    
    @objc private func handleAudioSessionInterruption(notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            print("⚠️ [AudioPlayerService] Invalid interruption notification")
            return
        }
        
        switch type {
        case .began:
            print("🔇 [AudioPlayerService] Audio interruption began (call incoming)")
            wasPlayingBeforeInterruption = isPlaying
            if isPlaying {
                pause()
            }
            
        case .ended:
            print("🔊 [AudioPlayerService] Audio interruption ended (call ended)")
            
            guard let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt else {
                print("⚠️ [AudioPlayerService] No interruption options provided")
                return
            }
            
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            
            if options.contains(.shouldResume) && wasPlayingBeforeInterruption {
                print("▶️ [AudioPlayerService] Auto-resuming playback after interruption")
                
                // Small delay to ensure audio session is ready
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.play()
                }
            } else {
                print("⏸️ [AudioPlayerService] Not resuming - either not suggested by system or wasn't playing before")
            }
            
            wasPlayingBeforeInterruption = false
            
        @unknown default:
            print("❓ [AudioPlayerService] Unknown interruption type: \(type.rawValue)")
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
            print("🎧 [AudioPlayerService] Audio device disconnected")
            if isPlaying {
                pause()
            }
            
        case .newDeviceAvailable:
            print("🎧 [AudioPlayerService] New audio device connected")
            
        default:
            break
        }
    }
    
    private func setupRemoteTransportControls() {
        print("🎵 [AudioPlayerService] Setting up remote transport controls...")
        
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
        
        print("✅ [AudioPlayerService] Remote transport controls setup complete")
    }
    
    // MARK: - Artwork Setup
    private func setupDefaultArtwork() {
        print("🎵 [AudioPlayerService] Setting up default artwork...")
        
        // Try to load app icon as artwork
        if let appIcon = UIImage(named: "AppIcon") ?? UIImage(systemName: "book.closed") {
            let artwork = MPMediaItemArtwork(boundsSize: appIcon.size) { size in
                return appIcon
            }
            defaultArtwork = artwork
            print("✅ [AudioPlayerService] Default artwork created successfully")
        } else {
            print("⚠️ [AudioPlayerService] Could not create default artwork - using system icon")
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
        print("🎵 [AudioPlayerService] Queued load for Surah: \(surah.englishName), Reciter: \(reciter.englishName)")
        Task {
            await loadAndPlay(surah: surah, reciter: reciter)
        }
    }
    
    func play() {
        if player?.currentItem != nil {
            print("🎵 [AudioPlayerService] Play requested")
            
            guard let player = player else {
                print("❌ [AudioPlayerService] No player available")
                return
            }
            
            // Ensure audio session is active
            if !isAudioSessionActive {
                print("🎵 [AudioPlayerService] Reactivating audio session for playback")
                setupAudioSession()
            } else {
                print("🎵 [AudioPlayerService] Audio session is already active")
            }
            print("🎵 [AudioPlayerService] Audio session active: \(isAudioSessionActive)")
            player.play()
            isPlaying = true
            lastRecordedTime = currentTime // Reset tracking when playback starts
            updateNowPlayingInfo()
            print("✅ [AudioPlayerService] Playback started")
        }
    }
    
    func pause() {
        print("🎵 [AudioPlayerService] Pause requested")
        
        player?.pause()
        isPlaying = false
        updateNowPlayingInfo()
        saveLastPlayed()
        
        print("✅ [AudioPlayerService] Playback paused")
    }
    
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    func seek(to time: TimeInterval, completion: ((Bool) -> Void)? = nil) {
        print("🎵 [AudioPlayerService] Seeking to: \(time) seconds")
        
        guard let player = player else {
            print("❌ [AudioPlayerService] No player available for seeking")
            completion?(false)
            return
        }
        
        let cmTime = CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player.seek(to: cmTime) { [weak self] finished in
            if finished {
                print("✅ [AudioPlayerService] Seek completed to: \(time) seconds")
                self?.currentTime = time
                self?.updateNowPlayingInfo()
            } else {
                print("❌ [AudioPlayerService] Seek failed")
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
        print("🎵 [AudioPlayerService] Next verse requested")
        
        if repeatMode == .all {
            // Restart from beginning
            loadFullSurahAudio(surah: currentSurah!, reciter: currentReciter!)
        } else {
            print("🎵 [AudioPlayerService] No next verse available")
        }
    }
    
    func previousVerse() {
        print("🎵 [AudioPlayerService] Previous verse requested")
        
        print("🎵 [AudioPlayerService] No previous verse available")
    }
    
    // MARK: - Track Management
    private func loadFullSurahAudio(surah: Surah, reciter: Reciter) {
        print("🎵 [AudioPlayerService] Loading full surah audio from Quran Foundation API")
        isLoading = true
        isReadyToPlay = false
        
        Task {
            do {
                // Get full surah audio URL from Quran Foundation API
                let audioURLString = try await QuranAPIService.shared.constructAudioURL(surahNumber: surah.number, reciter: reciter)
                print("🎵 [AudioPlayerService] Got full surah audio URL: \(audioURLString)")
                
                guard let url = URL(string: audioURLString) else {
                    print("❌ [AudioPlayerService] Invalid audio URL: \(audioURLString)")
                    await MainActor.run {
                        self.errorMessage = "Invalid audio URL"
                        self.isLoading = false
                    }
                    return
                }
                
                print("❗️❗️❗️ [AudioPlayerService] FINAL URL FOR PLAYER: \(url.absoluteString) ❗️❗️❗️")
                
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
                    print("✅ [AudioPlayerService] Full surah audio loaded successfully")
                }
                
            } catch {
                print("❌ [AudioPlayerService] Failed to load full surah audio: \(error)")
                await MainActor.run {
                    self.errorMessage = "Failed to load audio: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    private func setupTimeObserver() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.currentTime = time.seconds
            self?.updatePlaybackTime()
            
            // Track listening time during playback
            if let self = self, self.isPlaying {
                let currentPlaybackTime = time.seconds
                if self.lastRecordedTime > 0 {
                    let timeDifference = currentPlaybackTime - self.lastRecordedTime
                    // Only add time if it's a reasonable increment (0.3 to 1.0 seconds)
                    if timeDifference > 0.3 && timeDifference < 1.0 {
                        self.addListeningTime(timeDifference)
                    }
                }
                self.lastRecordedTime = currentPlaybackTime
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
        print("🎵 [AudioPlayerService] Full surah completed")
        
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
            print("⚠️ [AudioPlayerService] Cannot go to next track, playlist is empty.")
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
            print("🎵 [AudioPlayerService] End of playlist reached.")
            pause() // Or handle as desired
        }
    }
    
    func previousTrack() {
        guard !currentPlaylist.isEmpty, let currentReciter = currentReciter else {
            print("⚠️ [AudioPlayerService] Cannot go to previous track, playlist or reciter is missing.")
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
            print("🎵 [AudioPlayerService] Beginning of playlist reached.")
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
        
        print("🎵 [AudioPlayerService] Player item status changed to: \(playerItem.status.rawValue)")
        
        switch playerItem.status {
        case .readyToPlay:
            print("✅ [AudioPlayerService] Audio ready to play")
            isLoading = false
            duration = playerItem.duration.seconds
            print("🎵 [AudioPlayerService] Duration: \(duration) seconds")
            
            // Update Now Playing info with duration
            updateNowPlayingInfo()
            
            // Automatically start playing
            DispatchQueue.main.async { [weak self] in
                self?.play()
            }
            
        case .failed:
            print("❌ [AudioPlayerService] Audio loading failed")
            isLoading = false
            if let error = playerItem.error {
                print("❌ [AudioPlayerService] Error: \(error.localizedDescription)")
                print("❌ [AudioPlayerService] Error details: \(error)")
                errorMessage = error.localizedDescription
            } else {
                print("❌ [AudioPlayerService] Unknown error occurred")
                errorMessage = "Failed to load audio"
            }
            
        case .unknown:
            print("⏳ [AudioPlayerService] Audio status unknown - still loading...")
            break
            
        @unknown default:
            print("❓ [AudioPlayerService] Unknown player item status")
            break
        }
    }
    
    private func handleLoadedTimeRanges() {
        guard let playerItem = player?.currentItem else { return }
        
        let ranges = playerItem.loadedTimeRanges
        if let range = ranges.first {
            let duration = CMTimeGetSeconds(range.timeRangeValue.duration)
            print("🎵 [AudioPlayerService] Loaded time range: \(duration) seconds")
        }
    }
    
    // MARK: - Now Playing Info
    private func updateNowPlayingInfo() {
        guard let surah = currentSurah, let reciter = currentReciter else { 
            print("🎵 [AudioPlayerService] No current surah/reciter for Now Playing info")
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
        
        print("🎵 [AudioPlayerService] Updated Now Playing: \(surah.englishName) by \(reciter.englishName)")
        print("   - Title: \(nowPlayingInfo[MPMediaItemPropertyTitle] ?? "Unknown")")
        print("   - Artist: \(nowPlayingInfo[MPMediaItemPropertyArtist] ?? "Unknown")")
        print("   - Duration: \(nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] ?? "Unknown")")
        print("   - Current Time: \(nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] ?? "Unknown")")
        print("   - Is Playing: \(isPlaying)")
    }
    
    // MARK: - Clear Current Audio
    private func clearCurrentAudio() {
        print("🎵 [AudioPlayerService] Clearing current audio state...")
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
        
        // Clear Now Playing info
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        
        print("🎵 [AudioPlayerService] Audio state cleared")
    }
    
    // MARK: - Cleanup
    deinit {
        print("🎵 [AudioPlayerService] Deallocating audio player service")
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
        print("🔁 [AudioPlayerService] Repeat mode is now \(repeatMode.rawValue).")
    }
    
    // MARK: - Load All Surahs (for navigation)
    func loadAllSurahs(_ surahs: [Surah]) {
        allSurahs = surahs.sorted { $0.number < $1.number }
        print("🎵 [AudioPlayerService] Loaded \(allSurahs.count) surahs for navigation")
    }
    
    // MARK: - Shuffle Functionality
    func toggleShuffle() {
        isShuffleEnabled.toggle()
        print("🔀 [AudioPlayerService] Shuffle mode is now \(isShuffleEnabled ? "ON" : "OFF").")
        
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
        print("🎵 [AudioPlayerService] Preloading last played audio in background")
        
        guard let lastPlayedInfo = getLastPlayedInfo() else {
            print("❌ [AudioPlayerService] No last played data found for preloading")
            return
        }
        
        print("🎵 [AudioPlayerService] Preloading: \(lastPlayedInfo.surah.englishName) by \(lastPlayedInfo.reciter.englishName)")
        
        Task {
            await preloadAudio(surah: lastPlayedInfo.surah, reciter: lastPlayedInfo.reciter, startTime: lastPlayedInfo.time)
        }
    }
    
    // MARK: - Continue Last Played
    func continueLastPlayed() -> Bool {
        print("🎵 [AudioPlayerService] Attempting to continue last played")
        
        guard let lastPlayedInfo = getLastPlayedInfo() else {
            print("❌ [AudioPlayerService] No last played data found")
            return false
        }
        
        // Check if audio is already preloaded
        if let surah = preloadedSurah, let reciter = preloadedReciter,
           surah.id == lastPlayedInfo.surah.id && reciter.id == lastPlayedInfo.reciter.id,
           isPreloaded && isReadyToPlay {
            print("✅ [AudioPlayerService] Audio already preloaded, activating and playing immediately")
            
            // Now expose the preloaded audio to the UI
            currentSurah = surah
            currentReciter = reciter
            isPreloaded = false
            
            // Log to recents manager now that user is actually playing
            RecentsManager.shared.addTrack(surah: surah, reciter: reciter)
            
            seek(to: lastPlayedInfo.time) { [weak self] completed in
                if completed {
                    self?.play()
                } else {
                    print("⚠️ [AudioPlayerService] Seek failed, playing from current position")
                    self?.play()
                }
            }
            return true
        }
        
        print("🎵 [AudioPlayerService] Audio not preloaded, loading: \(lastPlayedInfo.surah.englishName) by \(lastPlayedInfo.reciter.englishName) at \(lastPlayedInfo.time)s")
        
        Task {
            await loadAndPlay(surah: lastPlayedInfo.surah, reciter: lastPlayedInfo.reciter, startTime: lastPlayedInfo.time)
        }
        
        return true
    }
    
    // MARK: - Save Last Played
    func saveLastPlayed() {
        guard let surah = currentSurah, let reciter = currentReciter else { return }
        
        do {
            let surahData = try JSONEncoder().encode(surah)
            let reciterData = try JSONEncoder().encode(reciter)
            
            UserDefaults.standard.set(surahData, forKey: lastPlayedSurahKey)
            UserDefaults.standard.set(reciterData, forKey: lastPlayedReciterKey)
            UserDefaults.standard.set(currentTime, forKey: lastPlayedTimeKey)
            
            print("🎵 [AudioPlayerService] Saved last played: \(surah.englishName) by \(reciter.englishName)")
        } catch {
            print("❌ [AudioPlayerService] Failed to save last played: \(error)")
        }
    }
    
    // MARK: - Sleep Timer
    func setSleepTimer(minutes: Double) {
        cancelSleepTimer() // Invalidate any existing timer
        let timeInSeconds = minutes * 60
        self.sleepTimeRemaining = timeInSeconds
        
        print("⏰ [AudioPlayerService] Sleep timer set for \(minutes) minutes.")
        
        self.sleepTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            if let remaining = self.sleepTimeRemaining {
                if remaining > 1 {
                    self.sleepTimeRemaining = remaining - 1
                } else {
                    print("⏰ [AudioPlayerService] Sleep timer finished. Pausing playback.")
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
        print("⏰ [AudioPlayerService] Sleep timer cancelled.")
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
        completedSurahNumbers.insert(surah.number)
        // Persist the completed surahs
        let completedArray = Array(completedSurahNumbers)
        UserDefaults.standard.set(completedArray, forKey: "completedSurahNumbers")
    }
    
    func addListeningTime(_ seconds: TimeInterval) {
        totalListeningTime += seconds
        // Persist the total listening time
        UserDefaults.standard.set(totalListeningTime, forKey: "totalListeningTime")
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
        print("🖼️ [AudioPlayerService] Updating artwork without reloading player.")
        self.currentArtwork = newImage
        updateNowPlayingInfo()
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
                print("⚠️ [AudioPlayerService] Requested surah not found in the new playlist. Defaulting to first track.")
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
        }
        
        // Log the track to the recents manager
        RecentsManager.shared.addTrack(surah: surah, reciter: reciter)
        
        do {
            let audioURLString = try await QuranAPIService.shared.constructAudioURL(surahNumber: surah.number, reciter: reciter)
            guard let audioURL = URL(string: audioURLString) else {
                throw QuranAPIError.invalidURL
            }
            
            print("▶️ [AudioPlayerService] Playing from URL: \(audioURL.absoluteString)")
            
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
                        print("🎵 [AudioPlayerService] Seeking to last played time: \(time)s")
                        self.seek(to: time) { [weak self] completed in
                            if completed {
                                print("✅ [AudioPlayerService] Seek completed, starting playback")
                                self?.play()
                            } else {
                                print("⚠️ [AudioPlayerService] Seek failed, starting from beginning")
                                self?.play()
                            }
                    }
                    } else {
                        self.play() // Start playing immediately if no seek needed
                    }
                    
                    print("✅ [AudioPlayerService] Player item is ready to play.")
                } else if item.status == .failed {
                    print("❌ [AudioPlayerService] Player item failed to load.")
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
            print("❌ [AudioPlayerService] \(errorDescription)")
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
        print("🎵 [AudioPlayerService] Preloading audio: \(surah.englishName) by \(reciter.englishName)")
        
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
                print("⚠️ [AudioPlayerService] Requested surah not found in the new playlist. Defaulting to first track.")
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
        
        do {
            let audioURLString = try await QuranAPIService.shared.constructAudioURL(surahNumber: surah.number, reciter: reciter)
            guard let audioURL = URL(string: audioURLString) else {
                throw QuranAPIError.invalidURL
            }
            
            print("🔄 [AudioPlayerService] Preloading from URL: \(audioURL.absoluteString)")
            
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
                        print("🎵 [AudioPlayerService] Preloading: seeking to saved position: \(time)s")
                        self.seek(to: time) { completed in
                            if completed {
                                print("✅ [AudioPlayerService] Preload seek completed, ready for instant play")
                            } else {
                                print("⚠️ [AudioPlayerService] Preload seek failed")
                            }
                        }
                    }
                    
                    print("✅ [AudioPlayerService] Audio preloaded and ready for instant playback")
                } else if item.status == .failed {
                    print("❌ [AudioPlayerService] Failed to preload audio")
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
            print("❌ [AudioPlayerService] \(errorDescription)")
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
        print("🏗️ [AudioPlayerService] Building playlist for reciter: \(reciter.englishName)")
        
        // Fetch all 114 surahs to serve as the master list
        guard let allSurahs = try? await QuranAPIService.shared.fetchSurahs() else {
            print("❌ [AudioPlayerService] Could not fetch master surah list to build playlist.")
            await MainActor.run {
                self.currentPlaylist = []
            }
            return
        }
        
        var availableSurahs: [Surah] = []
        let quranCentralPrefix = "qurancentral_"

        if reciter.identifier.hasPrefix(quranCentralPrefix) {
            let slug = String(reciter.identifier.dropFirst(quranCentralPrefix.count))
            if let availableNumbers = try? await QuranCentralService.shared.fetchAvailableSurahNumbers(for: slug) {
                availableSurahs = allSurahs.filter { availableNumbers.contains($0.number) }
                print("✅ [AudioPlayerService] Found \(availableSurahs.count) available surahs for Quran Central reciter.")
            } else {
                print("⚠️ [AudioPlayerService] Could not fetch available surah numbers for Quran Central reciter. Playlist will be empty.")
            }
        } else {
            // For MP3Quran reciters, assume all 114 are available as per previous logic.
            availableSurahs = allSurahs
            print("✅ [AudioPlayerService] Assuming all 114 surahs are available for MP3Quran reciter.")
        }
        
        await MainActor.run {
            self.currentPlaylist = availableSurahs
            
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
            print("💔 [AudioPlayerService] Unliked: Surah \(surahNumber) by \(reciterIdentifier)")
        } else {
            likedItems.insert(item)
            print("❤️ [AudioPlayerService] Liked: Surah \(surahNumber) by \(reciterIdentifier)")
        }
        
        saveLikedItems()
    }
    
    private func saveLikedItems() {
        do {
            let data = try JSONEncoder().encode(likedItems)
            UserDefaults.standard.set(data, forKey: likedItemsKey)
        } catch {
            print("❌ [AudioPlayerService] Failed to encode liked items: \(error)")
        }
    }
} 