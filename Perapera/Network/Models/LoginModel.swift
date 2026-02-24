//
//  LoginModel.swift
//  Perapera
//
//  Created by Perapera on 2024.
//

import Foundation
import HandyJSON

class LoginModel: HandyJSON, ResponseStatusable {
    var access_token: String = ""
    var token_type: String = ""
    var statusCode: Int?
    
    required init() {}
}

class UserInfoModel: HandyJSON {
    var uid: String = ""
    var email: String = ""
    var nickname: String = ""
    var avatar: String = ""
    
    required init() {}
}
