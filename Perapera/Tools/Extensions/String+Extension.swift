import Foundation

extension String {
    func localized() -> String {
        return NSLocalizedString(self, bundle: LanguageManager.currentBundle(), comment: "")
    }
}
