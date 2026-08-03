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
    }

    func logout() {
        clearLocalUser()
    }

    /// Fetches the current user profile from `GET /users/me` and stores it.
    /// The profile carries Pro membership info (annual/monthly expire dates),
    /// surfaced via `UserInfoModel.hasActivePro` and `remainingProTimeDescription()`.
    func fetchCurrentUser() {
        guard isLoggedIn else { return }
        appApi.rx.request(.currentUser)
            .asObservable()
            .mapObject(UserInfoModel.self)
            .subscribe(onNext: { [weak self] model in
                DispatchQueue.main.async {
                    self?.currentUserInfo = model
                }
            }, onError: { error in
                print("fetchCurrentUser failed: \(error.localizedDescription)")
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
