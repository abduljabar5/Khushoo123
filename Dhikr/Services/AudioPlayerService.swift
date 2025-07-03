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
    @Published var isAutoplayEnabled: Bool = false
    @Published var currentArtwork: UIImage?
    
    // MARK: - Private Properties
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var isAudioSessionActive = false
    private var allSurahs: [Surah] = []
    private var currentSurahIndex: Int = 0
    private var shuffledSurahIndices: [Int] = []
    private var defaultArtwork: MPMediaItemArtwork?
    private var currentArtworkImage: UIImage?
    
    // MARK: - UserDefaults Keys
    private let lastPlayedSurahKey = "lastPlayedSurah"
    private let lastPlayedReciterKey = "lastPlayedReciter"
    private let lastPlayedTimeKey = "lastPlayedTime"
    
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
    
    // MARK: - Playback Controls
    func play() {
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
        updateNowPlayingInfo()
        print("✅ [AudioPlayerService] Playback started")
    }
    
    func pause() {
        print("🎵 [AudioPlayerService] Pause requested")
        
        player?.pause()
        isPlaying = false
        updateNowPlayingInfo()
        
        print("✅ [AudioPlayerService] Playback paused")
    }
    
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    func seek(to time: TimeInterval) {
        print("🎵 [AudioPlayerService] Seeking to: \(time) seconds")
        
        guard let player = player else {
            print("❌ [AudioPlayerService] No player available for seeking")
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
    func load(surah: Surah, reciter: Reciter, artwork: UIImage? = nil) {
        print("🎵 [AudioPlayerService] ===== LOADING NEW SURAH ======")
        print("🎵 [AudioPlayerService] Surah Details:")
        print("   - Number: \(surah.number)")
        print("   - Name: \(surah.englishName)")
        print("   - Arabic Name: \(surah.name)")
        print("   - Translation: \(surah.englishNameTranslation)")
        print("🎵 [AudioPlayerService] Reciter Details:")
        print("   - Identifier: \(reciter.identifier)")
        print("   - Name: \(reciter.englishName)")
        print("   - Arabic Name: \(reciter.name)")
        
        // Ensure audio session is active
        if !isAudioSessionActive {
            print("🎵 [AudioPlayerService] Activating audio session for new surah")
            setupAudioSession()
        }
        
        // Clear any existing audio
        clearCurrentAudio()
        
        // Set current surah and reciter
        currentSurah = surah
        currentReciter = reciter
        currentArtwork = artwork
        
        // Update current surah index
        if let index = allSurahs.firstIndex(where: { $0.number == surah.number }) {
            currentSurahIndex = index
        }
        
        // Save as last played
        saveLastPlayed()
        
        // Load full surah audio
        loadFullSurahAudio(surah: surah, reciter: reciter)
    }
    
    private func loadFullSurahAudio(surah: Surah, reciter: Reciter) {
        print("🎵 [AudioPlayerService] Loading full surah audio from Quran Foundation API")
        isLoading = true
        isReadyToPlay = false
        
        Task {
            do {
                // Get full surah audio URL from Quran Foundation API
                let audioURLString = try QuranAPIService.shared.constructAudioURL(surahNumber: surah.number, reciter: reciter)
                print("🎵 [AudioPlayerService] Got full surah audio URL: \(audioURLString)")
                
                guard let url = URL(string: audioURLString) else {
                    print("❌ [AudioPlayerService] Invalid audio URL: \(audioURLString)")
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
                    selector: #selector(playerDidFinishPlaying),
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
            self?.updateNowPlayingInfo()
        }
    }
    
    @objc private func playerDidFinishPlaying() {
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
        print("🎵 [AudioPlayerService] Next track requested")
        
        guard !allSurahs.isEmpty, let currentReciter = currentReciter else {
            print("❌ [AudioPlayerService] No surahs or reciter available for next track")
            return
        }
        
        let nextIndex: Int
        if isShuffleEnabled {
            // Get next shuffled index
            if let currentShuffledIndex = shuffledSurahIndices.firstIndex(of: currentSurahIndex) {
                let nextShuffledIndex = (currentShuffledIndex + 1) % shuffledSurahIndices.count
                nextIndex = shuffledSurahIndices[nextShuffledIndex]
            } else {
                // If current surah not in shuffled list, start from beginning
                nextIndex = shuffledSurahIndices.first ?? 0
            }
        } else {
            // Sequential navigation
            nextIndex = (currentSurahIndex + 1) % allSurahs.count
        }
        
        let nextSurah = allSurahs[nextIndex]
        print("🎵 [AudioPlayerService] Loading next surah: \(nextSurah.englishName)")
        load(surah: nextSurah, reciter: currentReciter)
    }
    
    func previousTrack() {
        print("🎵 [AudioPlayerService] Previous track requested")
        
        guard !allSurahs.isEmpty, let currentReciter = currentReciter else {
            print("❌ [AudioPlayerService] No surahs or reciter available for previous track")
            return
        }
        
        let previousIndex: Int
        if isShuffleEnabled {
            // Get previous shuffled index
            if let currentShuffledIndex = shuffledSurahIndices.firstIndex(of: currentSurahIndex) {
                let previousShuffledIndex = currentShuffledIndex == 0 ? shuffledSurahIndices.count - 1 : currentShuffledIndex - 1
                previousIndex = shuffledSurahIndices[previousShuffledIndex]
            } else {
                // If current surah not in shuffled list, start from end
                previousIndex = shuffledSurahIndices.last ?? 0
            }
        } else {
            // Sequential navigation
            previousIndex = currentSurahIndex == 0 ? allSurahs.count - 1 : currentSurahIndex - 1
        }
        
        let previousSurah = allSurahs[previousIndex]
        print("🎵 [AudioPlayerService] Loading previous surah: \(previousSurah.englishName)")
        load(surah: previousSurah, reciter: currentReciter)
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
        deactivate()
    }
    
    // MARK: - Additional Controls
    func toggleRepeatMode() {
        print("🎵 [AudioPlayerService] Toggling repeat mode")
        switch repeatMode {
        case .off:
            repeatMode = .one
        case .one:
            repeatMode = .all
        case .all:
            repeatMode = .off
        }
        print("🎵 [AudioPlayerService] Repeat mode changed to: \(repeatMode)")
    }
    
    func toggleAutoplay() {
        isAutoplayEnabled.toggle()
        print("🎵 [AudioPlayerService] Autoplay is now \(isAutoplayEnabled ? "ON" : "OFF")")
    }
    
    func cyclePlaybackSpeed() {
        print("🎵 [AudioPlayerService] Cycling playback speed")
        let speeds: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
        
        if let currentIndex = speeds.firstIndex(of: playbackSpeed) {
            let nextIndex = (currentIndex + 1) % speeds.count
            playbackSpeed = speeds[nextIndex]
        } else {
            playbackSpeed = 1.0
        }
        
        // Apply speed to current player
        player?.rate = isPlaying ? playbackSpeed : 0.0
        
        print("🎵 [AudioPlayerService] Playback speed changed to: \(playbackSpeed)x")
        updateNowPlayingInfo()
    }
    
    // MARK: - Load All Surahs (for navigation)
    func loadAllSurahs(_ surahs: [Surah]) {
        allSurahs = surahs.sorted { $0.number < $1.number }
        print("🎵 [AudioPlayerService] Loaded \(allSurahs.count) surahs for navigation")
    }
    
    // MARK: - Shuffle Functionality
    func toggleShuffle() {
        isShuffleEnabled.toggle()
        print("🎵 [AudioPlayerService] Shuffle \(isShuffleEnabled ? "enabled" : "disabled")")
        
        if isShuffleEnabled {
            // Create shuffled indices excluding current surah
            var indices = Array(0..<allSurahs.count)
            indices.removeAll { $0 == currentSurahIndex }
            shuffledSurahIndices = indices.shuffled()
            // Add current surah at the beginning
            shuffledSurahIndices.insert(currentSurahIndex, at: 0)
        }
    }
    
    // MARK: - Continue Last Played
    func continueLastPlayed() -> Bool {
        print("🎵 [AudioPlayerService] Attempting to continue last played")
        
        guard let lastSurahData = UserDefaults.standard.data(forKey: lastPlayedSurahKey),
              let lastReciterData = UserDefaults.standard.data(forKey: lastPlayedReciterKey),
              let lastSurah = try? JSONDecoder().decode(Surah.self, from: lastSurahData),
              let lastReciter = try? JSONDecoder().decode(Reciter.self, from: lastReciterData) else {
            print("❌ [AudioPlayerService] No last played data found")
            return false
        }
        
        print("🎵 [AudioPlayerService] Found last played: \(lastSurah.englishName) by \(lastReciter.englishName)")
        load(surah: lastSurah, reciter: lastReciter)
        return true
    }
    
    // MARK: - Save Last Played
    private func saveLastPlayed() {
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
    }
    
    func addListeningTime(_ seconds: TimeInterval) {
        totalListeningTime += seconds
    }
    
    func getTotalListeningTimeString() -> String {
        let hours = Int(totalListeningTime) / 3600
        let minutes = (Int(totalListeningTime) % 3600) / 60
        let seconds = Int(totalListeningTime) % 60
        if hours > 0 {
            return String(format: "%dh %dm %ds", hours, minutes, seconds)
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
} 