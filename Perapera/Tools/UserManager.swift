//
//  UserManager.swift
//  Perapera
//
//  Created by Perapera on 2024.
//

import Foundation
import Combine
import HandyJSON

class UserManager: ObservableObject {
    static let shared = UserManager()
    
    @Published var currentUser: LoginModel?
    @Published var isLoggedIn: Bool = false
    @Published var userEmail: String?
    
    private let userKey = "kCurrentUser"
    private let emailKey = "kUserEmail"
    
    private init() {
        loadUser()
    }
    
    func save(model: LoginModel, email: String) {
        currentUser = model
        userEmail = email
        isLoggedIn = true
        // Persist to UserDefaults
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
        currentUser = nil
        userEmail = nil
        isLoggedIn = false
        PUserDefault.removeKey(key: userKey)
        PUserDefault.removeKey(key: emailKey)
    }
}
