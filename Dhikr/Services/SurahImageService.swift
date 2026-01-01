import Foundation
import FirebaseStorage
import FirebaseAuth
import UIKit

class SurahImageService {
    static let shared = SurahImageService()

    private let storage = Storage.storage()
    private let fileManager = FileManager.default
    private var cacheDirectory: URL?

    private init() {
        setupCacheDirectory()
    }

    // MARK: - Setup

    private func setupCacheDirectory() {
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ [SurahImageService] Could not access documents directory")
            return
        }

        let cacheDir = documentsDirectory.appendingPathComponent("SurahCovers", isDirectory: true)

        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: cacheDir.path) {
            do {
                try fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
                print("✅ [SurahImageService] Created cache directory at: \(cacheDir.path)")
            } catch {
                print("❌ [SurahImageService] Failed to create cache directory: \(error)")
            }
        }

        self.cacheDirectory = cacheDir
    }

    // MARK: - Public Methods

    /// Fetches surah cover image for the given surah number
    /// - Parameter surahNumber: The surah number (1-114)
    /// - Returns: UIImage if available, nil otherwise
    func fetchSurahCover(for surahNumber: Int) async -> UIImage? {
        // Check if user is authenticated
        guard Auth.auth().currentUser != nil else {
            print("⚠️ [SurahImageService] User not authenticated - cannot fetch surah cover")
            return nil
        }

        // Validate surah number
        guard surahNumber >= 1 && surahNumber <= 114 else {
            print("❌ [SurahImageService] Invalid surah number: \(surahNumber)")
            return nil
        }

        // Check local cache first
        if let cachedImage = loadFromCache(surahNumber: surahNumber) {
            print("✅ [SurahImageService] Loaded surah \(surahNumber) cover from cache")
            return cachedImage
        }

        // Fetch from Firebase Storage
        print("🔄 [SurahImageService] Fetching surah \(surahNumber) cover from Firebase Storage")
        return await downloadFromFirebase(surahNumber: surahNumber)
    }

    /// Prefetch multiple surah covers in background (for recently played/favorites)
    func prefetchCovers(for surahNumbers: [Int]) {
        Task {
            for surahNumber in surahNumbers {
                guard Auth.auth().currentUser != nil else { break }
                _ = await fetchSurahCover(for: surahNumber)
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
            // Download image data (max 10MB to handle larger cover images)
            let data = try await imageRef.data(maxSize: 10 * 1024 * 1024)

            guard let image = UIImage(data: data) else {
                print("❌ [SurahImageService] Failed to create image from data for surah \(surahNumber)")
                return nil
            }

            // Save to cache
            saveToCache(data: data, surahNumber: surahNumber)

            print("✅ [SurahImageService] Downloaded and cached surah \(surahNumber) cover")
            return image

        } catch {
            print("❌ [SurahImageService] Failed to download surah \(surahNumber) cover: \(error.localizedDescription)")
            return nil
        }
    }

    private func saveToCache(data: Data, surahNumber: Int) {
        guard let cacheDirectory = cacheDirectory else { return }

        let filePath = cacheDirectory.appendingPathComponent("surah-\(surahNumber).jpg")

        do {
            try data.write(to: filePath)
            print("✅ [SurahImageService] Saved surah \(surahNumber) cover to cache")
        } catch {
            print("❌ [SurahImageService] Failed to save surah \(surahNumber) cover to cache: \(error)")
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
            print("✅ [SurahImageService] Cleared all cached images")
        } catch {
            print("❌ [SurahImageService] Failed to clear cache: \(error)")
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
            print("❌ [SurahImageService] Failed to calculate cache size: \(error)")
            return 0
        }
    }
}
