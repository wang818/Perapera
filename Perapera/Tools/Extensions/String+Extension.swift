import Foundation

extension String {
    func localized() -> String {
        return NSLocalizedString(self, bundle: LanguageManager.currentBundle(), comment: "")
    }

    func localized(_ arguments: CVarArg...) -> String {
        let format = NSLocalizedString(self, bundle: LanguageManager.currentBundle(), comment: "")
        return String(format: format, arguments: arguments)
    }
}
