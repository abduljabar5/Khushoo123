//
//  OpenAIService.swift
//  Dhikr
//
//  Created by Abdul Jabar Nur on 20/07/2024.
//

import Foundation
import UIKit

// Custom Error for more descriptive API failures
enum OpenAIError: Error, LocalizedError {
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .apiError(let message):
            return message
        }
    }
}

class OpenAIService {
    private var apiKey: String? {
        return Secrets.openAIKey
    }

    private let apiURL = URL(string: "https://api.openai.com/v1/images/generations")!
    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 120 // 2-minute timeout
        self.session = URLSession(configuration: configuration)
    }

    private let sceneDescriptions = [
    "a secluded beach with golden sand and turquoise water",
    "a misty waterfall cascading over mossy rocks",
    "a dense ancient forest with sunlight piercing through tall trees",
    "a quiet river flowing through a canyon at sunrise",
    "a foggy pine woodland with wildflowers and rocky terrain",
    "a coastal cliffside with crashing waves below and dramatic skies",
    "a tranquil mountain lake surrounded by snowy peaks",
    "a lush rainforest with beams of light and thick canopy",
    "rolling green hills with scattered trees under a golden sky",
    "a winding forest trail carpeted with fallen autumn leaves",
    "a vibrant spring meadow with wildflowers and tall grass",
    "a desert oasis with palm trees and crystal-clear water",
    "an icy glacial valley with frozen rivers and blue light",
    "a volcanic jungle with steam vents and surreal lighting",
    "a fog-filled bamboo grove with dappled sunlight"]

    // List of beautiful, halal locations for prompt variety
    private let locations = [
        "the Black Forest, Germany",
        "Yosemite Valley, USA",
        "Sagano Bamboo Forest, Japan",
        "Plitvice Lakes National Park, Croatia",
        "Hallstatt Alps, Austria",
        "The Scottish Highlands",
        "Cameron Highlands, Malaysia",
        "The Amazon Rainforest, Brazil",
        "Mount Rainier National Park, USA",
        "The Lake District, England",
        "Pacific Northwest coastline, USA",
        "Fiordland National Park, New Zealand",
        "Isle of Skye, Scotland",
        "Arashiyama Forest, Japan",
        "Banff National Park, Canada",
        "Olympic National Park, USA",
        "Great Otway National Park, Australia",
        "Hoh Rainforest, Washington, USA",
        "Jotunheimen Mountains, Norway",
        "Waipoua Forest, New Zealand",
        "Zhangjiajie National Forest Park, China",
        "Cinque Terre cliffs, Italy",
        "Krka National Park, Croatia",
        "Cascades in Oregon, USA",
        "Seoraksan National Park, South Korea",
        "Patagonia, Argentina",
        "Borneo Rainforest, Malaysia",
        "Aoraki/Mount Cook National Park, New Zealand",
        "Redwood National Park, USA",
        "Valley of Five Lakes, Poland",
        "Tröllaskagi Peninsula, Iceland",
        "Munnar Hills, India",
        "Lofoten Islands, Norway",
        "Blue Mountains, Australia",
        "Rila Mountains, Bulgaria",
        "Andean cloud forest, Peru",
        "Valdivian rainforest, Chile",
        "Abel Tasman National Park, New Zealand",
        "Tatra Mountains, Slovakia",
        "Sundarbans Mangrove Forest, Bangladesh",
        "Carpathian Forest, Romania",
        "Khao Sok National Park, Thailand",
        "Lahemaa National Park, Estonia",
        "Dolomites, Italy",
        "Karkonosze Mountains, Poland",
        "Sinharaja Forest Reserve, Sri Lanka",
        "Taman Negara, Malaysia",
        "Alishan Forest, Taiwan",
        "Corsican forest, France",
        "Phong Nha-Kẻ Bàng National Park, Vietnam",
        "Drakensberg Mountains, South Africa",
        "Arenal Volcano rainforest, Costa Rica",
        "Jiuzhaigou Valley, China",
        "Kinabalu National Park, Borneo",
        "Tasmanian Wilderness, Australia",
        "Bwindi Impenetrable Forest, Uganda",
        "Chiloe Island Forests, Chile",
        "White Mountains, New Hampshire, USA",
        "Haleakalā rainforest, Hawaii, USA",
        "Isalo National Park, Madagascar"
    ]

    // MARK: - API Response Models
    private struct OpenAIResponse: Codable {
        let data: [ImageData]
    }

    private struct ImageData: Codable {
        let url: String?
        let b64_json: String?
    }

    // Model for decoding OpenAI's specific error response
    private struct OpenAIErrorResponse: Codable {
        struct ErrorDetail: Codable {
            let message: String
        }
        let error: ErrorDetail
    }

    // MARK: - Public API
    
    /// Generates an image URL for a given Surah name using the OpenAI DALL-E 3 model.
    /// - Parameter surahName: The English name of the Surah to generate an image for.
    /// - Returns: A URL pointing to the generated image.
    func generateImageURL(for surahName: String) async throws -> URL? {
        // Randomly select a location
        let location = locations.randomElement()
        guard let location = locations.randomElement(),
        let scene = sceneDescriptions.randomElement() else {
        throw URLError(.cannotCreateFile)
        }

        let prompt = """
        A breathtaking and highly realistic 4K portrait-mode image of \(scene), located in \(location). The scene is untouched by humans or animals. Focus on natural beauty, atmospheric lighting, and high realism. Include details like mist, water, cliffs, or foliage depending on the scene. Cinematic, peaceful, and sacred — pure nature with no man-made objects.
        """

        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey ?? "")", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let parameters: [String: Any] = [
            "model": "gpt-image-1",
            "prompt": prompt,
            "n": 1,
            "size": "1024x1536" // Portrait aspect ratio
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: parameters)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.cannotParseResponse)
        }
        
        // Check for a successful status code
        guard httpResponse.statusCode == 200 else {
            // If not successful, print the raw response and then try to decode the specific error
            if let responseString = String(data: data, encoding: .utf8) {
                print("❌ [OpenAIService] Raw error response from OpenAI: \(responseString)")
            }
            
            do {
                let errorResponse = try JSONDecoder().decode(OpenAIErrorResponse.self, from: data)
                throw OpenAIError.apiError(errorResponse.error.message)
            } catch {
                // If we can't decode the specific error, fall back to a generic one
                throw URLError(.badServerResponse, userInfo: [NSLocalizedDescriptionKey: "HTTP Status Code: \(httpResponse.statusCode)"])
            }
        }

        do {
            let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
            if let imageUrlString = openAIResponse.data.first?.url {
                return URL(string: imageUrlString)
            } else if let b64String = openAIResponse.data.first?.b64_json,
                      let imageData = Data(base64Encoded: b64String) {
                // Save the image to disk and return a file URL
                let filename = UUID().uuidString + ".png"
                let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
                try? imageData.write(to: fileURL)
                return fileURL
            } else {
                if let responseString = String(data: data, encoding: .utf8) {
                    print("❌ [OpenAIService] No image URL or b64_json found. Full response: \(responseString)")
                }
                return nil
            }
        } catch {
            // Print the full response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("❌ [OpenAIService] Decoding error. Full response: \(responseString)")
            }
            throw error
        }
    }
} 