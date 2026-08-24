//
//  UserManager.swift
//  Perapera
//
//  Created by Perapera on 2024.
//

import Foundation
import Combine
import HandyJSON
import Moya
import RxSwift

class UserManager: ObservableObject {
    static let shared = UserManager()

    @Published var currentUser: LoginModel?
    @Published var currentUserInfo: UserInfoModel?
    @Published var isLoggedIn: Bool = false
    @Published var userEmail: String?

    private let userKey = "kCurrentUser"
    private let userInfoKey = "kCurrentUserInfo"
    private let emailKey = "kUserEmail"
    private let disposeBag = DisposeBag()

    private init() {
        loadUser()
    }

    func save(model: LoginModel, email: String) {
        currentUser = model
        userEmail = email
        isLoggedIn = true
        if let json = model.toJSONString() {
            PUserDefault.setValueForKey(json, key: userKey)
        }
        PUserDefault.setValueForKey(email, key: emailKey)
    }

    func loadUser() {
        if let json = PUserDefault.getVauleForKey(key: userKey) as? String,
           let model = LoginModel.deserialize(from: json) {
            currentUser = model
            isLoggedIn = true
        } else {
            currentUser = nil
            isLoggedIn = false
        }

        if let email = PUserDefault.getVauleForKey(key: emailKey) as? String {
            userEmail = email
        }

        // 恢复上次持久化的用户资料（含会员剩余时间/到期时间），避免启动后接口返回前界面空白
        if let json = PUserDefault.getVauleForKey(key: userInfoKey) as? String,
           let model = UserInfoModel.deserialize(from: json) {
            currentUserInfo = model
        }

        // 旧版用单一全局 key 记录授权，升级后改为按账户(email)隔离；迁移一次即可
        migrateLegacyAIConsentIfNeeded()
    }

    // MARK: - AI / 第三方数据共享授权

    /// 已登录账户：按邮箱隔离的授权标记前缀
    private let aiConsentKeyPrefix = "hasConsentedAIDataSharing_"
    private let legacyAIConsentKey = "hasConsentedAIDataSharing"

    /// 是否已同意 AI / 第三方数据共享。未登录时返回 false（需先登录，登录后按账户判定）。
    var hasAIDataSharingConsent: Bool {
        guard let email = userEmail, !email.isEmpty else { return false }
        return UserDefaults.standard.bool(forKey: aiConsentKeyPrefix + email)
    }

    /// 记录当前登录账户的同意状态。仅在已登录（有邮箱）时生效。
    func setAIDataSharingConsent(_ value: Bool) {
        guard let email = userEmail, !email.isEmpty else { return }
        UserDefaults.standard.set(value, forKey: aiConsentKeyPrefix + email)
    }

    /// 旧版本用单一全局 key 记录授权，升级后改为按账户隔离；迁移一次即可。
    private func migrateLegacyAIConsentIfNeeded() {
        guard UserDefaults.standard.object(forKey: legacyAIConsentKey) != nil else { return }
        if let email = userEmail, !email.isEmpty,
           !UserDefaults.standard.bool(forKey: aiConsentKeyPrefix + email) {
            UserDefaults.standard.set(true, forKey: aiConsentKeyPrefix + email)
        }
        UserDefaults.standard.removeObject(forKey: legacyAIConsentKey)
    }

    func logout() {
        clearLocalUser()
    }

    /// Fetches the current user profile from `GET /users/me` and stores it.
    /// The profile carries Pro membership info (annual/monthly expire dates),
    /// surfaced via `UserInfoModel.hasActivePro` and `remainingProTimeDescription()`.
    func fetchCurrentUser(completion: ((UserInfoModel?) -> Void)? = nil) {
        guard isLoggedIn else {
            completion?(nil)
            return
        }
        let infoKey = userInfoKey
        appApi.rx.request(.currentUser)
            .asObservable()
            .mapObject(UserInfoModel.self)
            .subscribe(onNext: { [weak self] model in
                DispatchQueue.main.async { [self] in
                    self?.currentUserInfo = model
                    // 每次接口返回都更新本地为最新数据
                    if let json = model.toJSONString(),
                       let key = self?.userInfoKey {
                        PUserDefault.setValueForKey(json, key: infoKey)
                    }
                    completion?(model)
                }
            }, onError: { error in
                print("fetchCurrentUser failed: \(error.localizedDescription)")
                DispatchQueue.main.async { completion?(nil) }
            })
            .disposed(by: disposeBag)
    }

    private func clearLocalUser() {
        currentUser = nil
        userEmail = nil
        isLoggedIn = false
        PUserDefault.removeKey(key: userKey)
        PUserDefault.removeKey(key: emailKey)
        PUserDefault.removeKey(key: "access_token")
        PUserDefault.removeKey(key: userInfoKey)
    }

    func deleteAccount(completion: @escaping (Bool, String?) -> Void) {
        appApi.rx.request(.deleteAccount)
            .asObservable()
            .subscribe(onNext: { [weak self] response in
                if (200..<300).contains(response.statusCode) {
                    self?.clearLocalUser()
                    DispatchQueue.main.async {
                        completion(true, nil)
                    }
                } else {
                    var message: String?
                    if let json = try? response.mapJSON() as? [String: Any] {
                        message = (json["detail"] as? String)
                            ?? (json["message"] as? String)
                    }
                    DispatchQueue.main.async {
                        completion(false, message ?? "Delete account failed (\(response.statusCode)).")
                    }
                }
            }, onError: { error in
                DispatchQueue.main.async {
                    completion(false, error.localizedDescription)
                }
            })
            .disposed(by: disposeBag)
    }
}
