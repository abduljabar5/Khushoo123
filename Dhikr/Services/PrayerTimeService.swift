import Foundation
import CoreLocation

class PrayerTimeService {
    
    func fetchPrayerTimes(for location: CLLocation, on date: Date = Date()) async throws -> Timings {
        let latitude = location.coordinate.latitude
        let longitude = location.coordinate.longitude
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd-MM-yyyy"
        let dateString = dateFormatter.string(from: date)
        
        let urlString = "http://api.aladhan.com/v1/timings/\(dateString)?latitude=\(latitude)&longitude=\(longitude)&method=2"
        
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let prayerTimeResponse = try JSONDecoder().decode(PrayerTimeResponse.self, from: data)
        return prayerTimeResponse.data.timings
    }
} 