import Foundation

struct FavoriteReciterItem: Codable, Hashable {
    let identifier: String
    let dateAdded: Date

    init(identifier: String, dateAdded: Date = Date()) {
        self.identifier = identifier
        self.dateAdded = dateAdded
    }
} 