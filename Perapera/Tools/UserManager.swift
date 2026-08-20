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
        appApi.rx.request(.currentUser)
            .asObservable()
            .mapObject(UserInfoModel.self)
            .subscribe(onNext: { [weak self] model in
                DispatchQueue.main.async {
                    self?.currentUserInfo = model
                    // 每次接口返回都更新本地为最新数据
                    if let json = model.toJSONString() {
                        PUserDefault.setValueForKey(json, key: userInfoKey)
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
