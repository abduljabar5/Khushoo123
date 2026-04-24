//
//  BackgroundSoundService.swift
//  Dhikr
//
//  Plays ambient background sounds (rain, ocean, fire, etc.) layered
//  underneath the Quran audio. Uses AVAudioPlayer; multiple players
//  in the same process auto-mix, so no extra session config is needed.
//

import Foundation
import AVFoundation
import Combine

struct AmbientSound: Identifiable, Equatable {
    let id: String          // file name without extension
    let title: String       // display name
    let systemImage: String // SF Symbol

    static let all: [AmbientSound] = [
        AmbientSound(id: "rain",    title: "Rain",    systemImage: "cloud.rain"),
        AmbientSound(id: "thunder", title: "Thunder", systemImage: "cloud.bolt.rain"),
        AmbientSound(id: "ocean",   title: "Ocean",   systemImage: "water.waves"),
        AmbientSound(id: "forest",  title: "Forest",  systemImage: "leaf"),
        AmbientSound(id: "fire",    title: "Fire",    systemImage: "flame"),
        AmbientSound(id: "night",   title: "Night",   systemImage: "moon.stars")
    ]
}

@MainActor
final class BackgroundSoundService: ObservableObject {
    static let shared = BackgroundSoundService()

    @Published private(set) var currentSound: AmbientSound?
    @Published var volume: Float {
        didSet {
            player?.volume = volume
            UserDefaults.standard.set(volume, forKey: Self.volumeKey)
        }
    }

    private var player: AVAudioPlayer?
    private var quranPlayingCancellable: AnyCancellable?
    private static let volumeKey = "ambientSoundVolume"

    var isPlaying: Bool { player?.isPlaying == true }

    private init() {
        let stored = UserDefaults.standard.object(forKey: Self.volumeKey) as? Float
        self.volume = stored ?? 0.5

        // Mirror the Quran player's play/pause state so the ambient
        // sound stays in sync (pauses when Quran pauses, resumes with it).
        quranPlayingCancellable = AudioPlayerService.shared.$isPlaying
            .removeDuplicates()
            .sink { [weak self] quranIsPlaying in
                self?.syncWithQuran(isPlaying: quranIsPlaying)
            }
    }

    private func syncWithQuran(isPlaying quranIsPlaying: Bool) {
        guard let player = player else { return }
        if quranIsPlaying {
            if !player.isPlaying { player.play() }
        } else {
            if player.isPlaying { player.pause() }
        }
    }

    /// Start (or restart) playback of the given sound. Pass `nil` to stop.
    func play(_ sound: AmbientSound?) {
        guard let sound = sound else {
            stop()
            return
        }

        // Toggle off if the same sound is already playing
        if currentSound?.id == sound.id, isPlaying {
            stop()
            return
        }

        guard let url = Bundle.main.url(forResource: sound.id, withExtension: "mp3", subdirectory: "AmbientSounds")
                ?? Bundle.main.url(forResource: sound.id, withExtension: "mp3") else {
            print("⚠️ [BackgroundSound] Missing audio file for \(sound.id)")
            return
        }

        do {
            let newPlayer = try AVAudioPlayer(contentsOf: url)
            newPlayer.numberOfLoops = -1   // loop indefinitely
            newPlayer.volume = volume
            newPlayer.prepareToPlay()
            newPlayer.play()

            player = newPlayer
            currentSound = sound
        } catch {
            print("❌ [BackgroundSound] Failed to play \(sound.id): \(error)")
        }
    }

    func stop() {
        player?.stop()
        player = nil
        currentSound = nil
    }
}
