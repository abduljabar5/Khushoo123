//
//  ImageCacheManager.swift
//  Dhikr
//
//  Created by Performance Optimization
//

import Foundation
import Kingfisher
import UIKit

class ImageCacheManager {
    static let shared = ImageCacheManager()
    
    private init() {
        configureKingfisher()
    }
    
    private func configureKingfisher() {
        // Configure global image cache settings for optimal performance
        let cache = ImageCache.default
        
        // Set memory cache limits (50MB for memory, 200MB for disk)
        cache.memoryStorage.config.totalCostLimit = 50 * 1024 * 1024 // 50MB
        cache.diskStorage.config.sizeLimit = 200 * 1024 * 1024 // 200MB
        
        // Set expiration times
        cache.memoryStorage.config.expiration = .seconds(300) // 5 minutes in memory
        cache.diskStorage.config.expiration = .days(7) // 7 days on disk
        
        // Configure downloader for better performance
        let downloader = ImageDownloader.default
        downloader.downloadTimeout = 10.0 // 10 second timeout

    }
    
    // MARK: - Optimized Image Loading Options
    static var standardOptions: KingfisherOptionsInfo {
        return [
            .transition(.fade(0.3)),
            .cacheMemoryOnly, // Prioritize memory cache for speed
            .backgroundDecode, // Decode images in background
            .scaleFactor(UIScreen.main.scale), // Use device scale factor
            .processor(DownsamplingImageProcessor(size: CGSize(width: 400, height: 400))), // Downsample for memory efficiency
            .loadDiskFileSynchronously // Load from disk cache synchronously for better UX
        ]
    }
    
    static var thumbnailOptions: KingfisherOptionsInfo {
        return [
            .transition(.fade(0.2)),
            .cacheMemoryOnly,
            .backgroundDecode,
            .scaleFactor(UIScreen.main.scale),
            .processor(DownsamplingImageProcessor(size: CGSize(width: 150, height: 150))), // Smaller thumbnails
            .loadDiskFileSynchronously
        ]
    }
    
    static var fullScreenOptions: KingfisherOptionsInfo {
        return [
            .transition(.fade(0.5)),
            .backgroundDecode,
            .scaleFactor(UIScreen.main.scale),
            .processor(DownsamplingImageProcessor(size: CGSize(width: 800, height: 800))), // Higher quality for full screen
            .loadDiskFileSynchronously
        ]
    }
    
    // MARK: - Memory Management
    func clearMemoryCache() {
        ImageCache.default.clearMemoryCache()
    }
    
    func clearExpiredDiskCache() {
        ImageCache.default.cleanExpiredDiskCache { 
        }
    }
    
    // MARK: - Preloading for Performance
    func preloadImages(urls: [URL], completion: @escaping () -> Void) {
        let prefetcher = ImagePrefetcher(urls: urls, options: Self.thumbnailOptions)
        prefetcher.start()
        
        // Complete after a reasonable timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            completion()
        }
    }
} 