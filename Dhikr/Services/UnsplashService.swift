//
//  UnsplashService.swift
//  Dhikr
//
//  Created by Abduljabar Nur on 1723145405.0.
//

import Foundation

// MARK: - Unsplash API Models
struct UnsplashSearchResponse: Codable {
    let results: [UnsplashPhoto]
}

struct UnsplashPhoto: Codable {
    let id: String
    let urls: UnsplashPhotoURLs
}

struct UnsplashPhotoURLs: Codable {
    let raw: String
    let full: String
    let regular: String
    let small: String
    let thumb: String
}

// MARK: - Error Enum
enum UnsplashError: Error {
    case invalidURL
    case networkError(statusCode: Int?)
    case decodingError
    case noImagesFound
}

// MARK: - API Service
class UnsplashService {
    
    static let shared = UnsplashService()
    private init() {}

    // IMPORTANT: For a production app, you should not hardcode your keys here.
    // Store them securely, for example in a .xcconfig file or using environment variables.
    private let accessKey = "UX1-nI5KL_HYR8At_LeMKtWvAc2VPSTOsso7tooICyI"
    private let apiBaseURL = "https://api.unsplash.com/"

    /// Fetches a URL for a random, high-quality, landscape-oriented nature photo.
    func fetchNatureImageURL(query: String) async throws -> URL {
        print("🏞️ [UnsplashService] Fetching nature image for query: \(query)")
        
        var components = URLComponents(string: "\(apiBaseURL)search/photos")!
        components.queryItems = [
            URLQueryItem(name: "query", value: "\(query) nature wallpaper 4k"),
            URLQueryItem(name: "orientation", value: "portrait"),
            URLQueryItem(name: "content_filter", value: "high"),
            URLQueryItem(name: "per_page", value: "20") // Fetch a few to pick from
        ]
        
        guard let url = components.url else {
            throw UnsplashError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Client-ID \(accessKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode
            print("❌ [UnsplashService] Network error with status code: \(statusCode ?? -1)")
            throw UnsplashError.networkError(statusCode: statusCode)
        }
        
        let searchResponse = try JSONDecoder().decode(UnsplashSearchResponse.self, from: data)
        
        guard let randomPhoto = searchResponse.results.randomElement(), let imageUrl = URL(string: randomPhoto.urls.raw) else {
            print("❌ [UnsplashService] No images found for query: \(query)")
            throw UnsplashError.noImagesFound
        }
        
        print("✅ [UnsplashService] Successfully fetched image URL: \(imageUrl.absoluteString)")
        return imageUrl
    }
} 