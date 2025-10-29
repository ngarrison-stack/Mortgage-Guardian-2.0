import SwiftUI

struct AppTheme {
    static let primaryGreen = Color(red: 0.2, green: 0.6, blue: 0.5) // Teal-green from logo
    static let secondaryBlue = Color(red: 0.4, green: 0.7, blue: 0.8) // Light blue from logo
    static let darkBlue = Color(red: 0.1, green: 0.2, blue: 0.4) // Navy blue from logo
    static let accentGold = Color(red: 1.0, green: 0.8, blue: 0.0) // Gold from checkmarks
    
    static let gradient = LinearGradient(
        colors: [primaryGreen, secondaryBlue],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}