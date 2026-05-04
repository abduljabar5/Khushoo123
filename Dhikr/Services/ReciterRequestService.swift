//
//  ReciterRequestService.swift
//  Dhikr
//
//  Two write-only Firestore surfaces that drive catalog growth:
//
//  1. reciter_requests: explicit user submissions ("please add Sheikh X")
//  2. reciter_search_no_results: passive log of searches that returned zero hits
//
//  Both collections are write-only from clients (rules enforce); console reads
//  the data weekly to prioritize which reciters to upload to Cloudflare R2 next.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
class ReciterRequestService {
    static let shared = ReciterRequestService()

    private let db = Firestore.firestore()

    /// In-memory de-dupe so a single user typing "mishari" → "mishari k" → "mishari kn"
    /// only logs once per session per normalized query.
    private var loggedQueriesThisSession: Set<String> = []

    private init() {}

    // MARK: - Explicit Reciter Request

    /// Submit a user-suggested reciter. `name` is required; `note` is optional context
    /// like riwayah, country, or where they heard the reciter.
    func submitRequest(name: String, note: String?) async throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let user = Auth.auth().currentUser
        var data: [String: Any] = [
            "name": trimmedName,
            "timestamp": FieldValue.serverTimestamp(),
            "userId": user?.uid ?? "anonymous",
            "isPremium": SubscriptionService.shared.hasPremiumAccess,
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            "platform": "iOS"
        ]

        // Attach the user's email if they're signed in — lets us notify them
        // when the requested reciter actually goes live in the catalog.
        if let email = user?.email, !email.isEmpty {
            data["userEmail"] = email
        }

        if let note = note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
            data["note"] = note
        }

        try await db.collection("reciter_requests").addDocument(data: data)
    }

    // MARK: - Zero-Result Search Log

    /// Record a search that found no reciters. Caller should debounce — this
    /// is intended to be invoked from the same place that updates `filteredReciters`,
    /// not on every keystroke.
    /// Skips:
    /// - queries shorter than 3 chars (noisy and not actionable)
    /// - duplicate queries within the same session (de-duped via a normalized key)
    func logZeroResultSearch(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard trimmed.count >= 3 else { return }
        guard !loggedQueriesThisSession.contains(trimmed) else { return }
        loggedQueriesThisSession.insert(trimmed)

        let data: [String: Any] = [
            "query": trimmed,
            "timestamp": FieldValue.serverTimestamp(),
            "userId": Auth.auth().currentUser?.uid ?? "anonymous",
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            "platform": "iOS"
        ]

        // Fire-and-forget — never block UI on logging
        db.collection("reciter_search_no_results").addDocument(data: data) { error in
            if let error = error {
                print("ReciterRequestService: logZeroResultSearch failed: \(error.localizedDescription)")
            }
        }
    }
}
