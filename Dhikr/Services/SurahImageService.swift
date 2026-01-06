import Foundation
import FirebaseStorage
import FirebaseAuth
import UIKit

class SurahImageService {
    static let shared = SurahImageService()

    private let storage = Storage.storage()
    private let fileManager = FileManager.default
    private var cacheDirectory: URL?

    /// Check if user can access premium cover art
    @MainActor
    private func canAccessPremiumCovers() -> Bool {
        return SubscriptionService.shared.isPremium
    }

    /// Ensure user has a valid Firebase Auth session for Storage access
    /// Signs in anonymously if premium but not authenticated
    private func ensureAuthenticatedForStorage() async -> Bool {
        // If already authenticated, we're good
        if Auth.auth().currentUser != nil {
            return true
        }

        // Check if user is premium (needs to be on MainActor)
        let isPremium = await MainActor.run { SubscriptionService.shared.isPremium }

        // If premium but not authenticated, sign in anonymously
        if isPremium {
            do {
                _ = try await Auth.auth().signInAnonymously()
                return true
            } catch {
                return false
            }
        }

        return false
    }

    private init() {
        setupCacheDirectory()
    }

    // MARK: - Setup

    private func setupCacheDirectory() {
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }

        let cacheDir = documentsDirectory.appendingPathComponent("SurahCovers", isDirectory: true)

        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: cacheDir.path) {
            do {
                try fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
            } catch {
            }
        }

        self.cacheDirectory = cacheDir
    }

    // MARK: - Public Methods

    /// Fetches surah cover image for the given surah number
    /// - Parameter surahNumber: The surah number (1-114)
    /// - Returns: UIImage if available, nil otherwise
    func fetchSurahCover(for surahNumber: Int) async -> UIImage? {
        // Check if user can access premium covers (premium OR authenticated)
        let hasAccess = await canAccessPremiumCovers()
        guard hasAccess else { return nil }

        // Validate surah number
        guard surahNumber >= 1 && surahNumber <= 114 else { return nil }

        // Check local cache first
        if let cachedImage = loadFromCache(surahNumber: surahNumber) {
            return cachedImage
        }

        // Ensure we have a valid Firebase Auth session for Storage access
        // This signs in anonymously if user is premium but not authenticated
        guard await ensureAuthenticatedForStorage() else { return nil }

        // Fetch from Firebase Storage
        return await downloadFromFirebase(surahNumber: surahNumber)
    }

    /// Prefetch multiple surah covers in background (for recently played/favorites)
    /// Limited to 5 concurrent downloads with throttling to avoid overwhelming Firebase
    func prefetchCovers(for surahNumbers: [Int]) {
        Task {
            // Ensure we have a valid Firebase Auth session before prefetching
            guard await ensureAuthenticatedForStorage() else { return }

            // Limit prefetch to first 10 items to avoid excessive downloads
            let limitedNumbers = Array(surahNumbers.prefix(10))

            for surahNumber in limitedNumbers {
                // Check if user can still access premium covers
                let hasAccess = await canAccessPremiumCovers()
                guard hasAccess else { break }

                // Skip if already cached
                if loadFromCache(surahNumber: surahNumber) != nil {
                    continue
                }

                _ = await fetchSurahCover(for: surahNumber)

                // Throttle: 500ms between downloads to avoid hammering Firebase
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
    }

    // MARK: - Private Methods

    private func loadFromCache(surahNumber: Int) -> UIImage? {
        guard let cacheDirectory = cacheDirectory else { return nil }

        let filePath = cacheDirectory.appendingPathComponent("surah-\(surahNumber).jpg")

        guard fileManager.fileExists(atPath: filePath.path),
              let imageData = try? Data(contentsOf: filePath),
              let image = UIImage(data: imageData) else {
            return nil
        }

        return image
    }

    private func downloadFromFirebase(surahNumber: Int) async -> UIImage? {
        let storageRef = storage.reference()
        let imageRef = storageRef.child("surah-covers/surah-\(surahNumber).jpg")

        do {
            // Download image data (max 10MB - allows for high quality covers)
            let data = try await imageRef.data(maxSize: 10 * 1024 * 1024)

            guard let image = UIImage(data: data) else {
                return nil
            }

            // Save to cache
            saveToCache(data: data, surahNumber: surahNumber)

            return image

        } catch {
            return nil
        }
    }

    private func saveToCache(data: Data, surahNumber: Int) {
        guard let cacheDirectory = cacheDirectory else { return }

        let filePath = cacheDirectory.appendingPathComponent("surah-\(surahNumber).jpg")

        do {
            try data.write(to: filePath)
        } catch {
        }
    }

    // MARK: - Cache Management

    /// Clear all cached images (useful for debugging or if user logs out)
    func clearCache() {
        guard let cacheDirectory = cacheDirectory else { return }

        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            for file in files {
                try fileManager.removeItem(at: file)
            }
        } catch {
        }
    }

    /// Get cache size in MB
    func getCacheSize() -> Double {
        guard let cacheDirectory = cacheDirectory else { return 0 }

        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey])
            let totalSize = files.reduce(0) { total, file in
                let size = (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                return total + size
            }
            return Double(totalSize) / (1024 * 1024) // Convert to MB
        } catch {
            return 0
        }
    }
}
