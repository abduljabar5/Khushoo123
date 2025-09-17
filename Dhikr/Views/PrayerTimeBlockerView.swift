import SwiftUI
import CoreLocationUI

// MARK: - Main View
// NOTE: This view has been replaced by PrayerTimeView
// Keeping empty implementation to avoid breaking existing references during migration
struct PrayerTimeBlockerView: View {
    var body: some View {
        // This view is deprecated - use PrayerTimeView instead
        PrayerTimeView()
    }
}

// MARK: - Preview
struct PrayerTimeBlockerView_Previews: PreviewProvider {
    static var previews: some View {
        PrayerTimeBlockerView()
    }
}