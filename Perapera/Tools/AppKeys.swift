import Foundation

/// A centralized place to store all app-wide keys (UserDefaults, Notifications, etc.)
struct AppKeys {
    // Prevent initialization
    private init() {}
    
    // MARK: - Language Manager
    static let savedLanguageNames = "kSavedLanguageNamesKey"
    static let appLanguage = "AppLanguage" //app默认语言
    static let aiLanguage = "AILanguage" // AI Language
    static let sourceLanguage = "SourceLanguage" // Source Language
    static let learningLanguage = "LearningLanguage" // Learning Language
    
    // MARK: - User Defaults (PUserDefault)
    static let coinImageKeyValues = "kCoinImageKeyValues"
    
    // MARK: - Other Keys
    // Add new keys here
}
