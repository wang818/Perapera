import Foundation

/// App-wide constants. Hard-coded literals (URLs, magic numbers) live here.
/// Using an enum as a namespace: cases are not allowed, so it cannot be instantiated.
enum AppConstants {
    // MARK: - Legal URLs
    static let privacyPolicyURL = URL(string: "https://www.perapera.cc/privacy.html")!
    static let termsOfUseURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}
