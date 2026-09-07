//
//  UserSettingsManager.swift
//  Perapera
//
//  Syncs the Language settings page with the backend `users_setting` API.
//  Only the second-subtitle (`app_second_subtitle`) and target-language
//  (`app_target_lang`) rows are server-synced; App Language and AI explanation
//  stay local-only. GET loads on open; PUT persists a single changed field.
//

import Foundation
import Moya
import RxSwift
import HandyJSON

/// Language fields on the Language settings page, mapped to the corresponding
/// `users_setting` request keys. Only `.source` and `.learning` are currently
/// synced to the backend; `.app` and `.ai` remain local-only (kept for reference).
enum UserSettingLanguageField: String {
    case app = "app_lang"
    case ai = "app_explan_lang"
    case source = "app_second_subtitle"
    case learning = "app_target_lang"
}

final class UserSettingsManager {
    static let shared = UserSettingsManager()
    private let disposeBag = DisposeBag()

    private init() {}

    /// Loads the current user settings from the backend and applies the four
    /// language fields into `LanguageManager` (server is the source of truth on open).
    /// `completion` is always called exactly once, on either success or failure,
    /// so the caller can refresh its displayed values.
    func fetchAndApply(completion: (() -> Void)? = nil) {
        guard UserManager.shared.isLoggedIn else {
            completion?()
            return
        }

        appApi.rx.request(.userSettingGet)
            .asObservable()
            .mapObject(UserSettingModel.self)
            .subscribe(onNext: { [weak self] model in
                self?.apply(model)
                completion?()
            }, onError: { _ in
                completion?()
            })
            .disposed(by: disposeBag)
    }

    /// Persists a single changed language field to the backend. No-op when the
    /// user is not logged in (local-only behavior in that case).
    func saveField(_ field: UserSettingLanguageField, value: String) {
        guard UserManager.shared.isLoggedIn else { return }

        let parameters: [String: Any] = [field.rawValue: value]
        appApi.rx.request(.userSettingUpdate(parameters: parameters))
            .asObservable()
            .mapObject(UserSettingModel.self)
            .subscribe(onNext: { _ in
                // Updated settings returned; local state already reflects the change.
            }, onError: { _ in
                // Network/API failure: local change is kept; a retry can be added later.
            })
            .disposed(by: disposeBag)
    }

    // MARK: - Private

    /// Applies only the server-synced fields. App Language (`app_lang`) and AI
    /// explanation (`app_explan_lang`) are intentionally NOT written here — they
    /// stay local-only.
    private func apply(_ model: UserSettingModel) {
        if !model.app_target_lang.isEmpty {
            LanguageManager.setLearningLanguage(model.app_target_lang)
        }
        if !model.app_second_subtitle.isEmpty {
            // Backend stores a language code; local second-subtitle stores the native name.
            LanguageManager.setSecondSubtitleLanguageName(
                LanguageManager.nativeLanguageName(for: model.app_second_subtitle)
            )
        }
    }
}
