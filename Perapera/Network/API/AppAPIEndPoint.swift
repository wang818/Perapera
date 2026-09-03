//
//  AppAPIEndPoint.swift
//  Perapera
//
//  Created by Perapera on 2024.
//

import Moya
import Foundation

enum AppAPIEndPoint {
    case test
    case userInfo
    case zendeskNotice(page: String, pagesize: String)
    case supportLang
    case supportSecondLang
    case targetLang
    case sendCaptcha(email: String)
    case login(email: String, captcha: String)
    case ytAudio(url: String)
    case ytInfo(url: String)
    case iapVerify(parameters: [String: Any])
    case iapStatus
    case iapProducts
    case iapRestore(parameters: [String: Any])
    case iapNotifications(payload: [String: Any])
    case iapProductEntitlement(productID: String)
    case deleteAccount
    case currentUser
    case refreshAccessToken
}

extension AppAPIEndPoint: TargetType {
    var baseURL: URL {
        return URL(string: "https://www.perapera.cc/api/v1/")!
    }
    
    var path: String {
        switch self {
        case .test: return "/test"
        case .userInfo: return "/user/info"
        case .zendeskNotice: return ""
        case .supportLang: return "common/support_lang"
        case .supportSecondLang: return "common/support_second_lang"
        case .targetLang: return "common/target_lang"
        case .sendCaptcha : return "auth/sendCaptcha"
        case .login : return "auth/login"
        case .ytAudio: return "common/yt_audio"
        case .ytInfo: return "common/yt_info"
        case .iapVerify: return "iap/verify"
        case .iapStatus: return "iap/status"
        case .iapProducts: return "iap/products"
        case .iapRestore: return "iap/restore"
        case .iapNotifications: return "iap/notifications"
        case .iapProductEntitlement(let productID): return "iap/products/\(productID)/entitlement"
        case .deleteAccount: return "users/delete_account"
        case .currentUser: return "users/me"
        case .refreshAccessToken: return "auth/refresh"

        }
    }
    
    var method: Moya.Method {
        switch self {
        case .zendeskNotice: return .get
        case .supportLang: return .get
        case .supportSecondLang: return .get
        case .targetLang: return .get
        case .sendCaptcha: return .get
        case .ytAudio: return .get
        case .ytInfo: return .get
        case .iapStatus: return .get
        case .iapProducts: return .get
        case .iapProductEntitlement: return .get
        case .currentUser: return .get
        case .deleteAccount: return .delete
        case .refreshAccessToken: return .post
        default: return .post
        }
    }

    
    var task: Task {
        switch self {
        case .zendeskNotice(let page, let pagesize):
            let params = ["page": page, "pagesize": pagesize]
            return .requestParameters(parameters: params, encoding: URLEncoding.default)
        case .sendCaptcha(let email):
            let params = ["email" : email]
            return .requestParameters(parameters: params, encoding: URLEncoding.default)
        case .ytAudio(let url):
            let params = ["url": url]
            return .requestParameters(parameters: params, encoding: URLEncoding.queryString)
        case .ytInfo(let url):
            let params = ["url": url]
            return .requestParameters(parameters: params, encoding: URLEncoding.queryString)
        case .login(let email, let captcha):
            let params = ["email" : email, "captcha" : captcha]
            return .requestParameters(parameters: params, encoding: JSONEncoding.default)
        case .iapVerify(let parameters):
            return .requestParameters(parameters: parameters, encoding: JSONEncoding.default)
        case .iapRestore(let parameters):
            return .requestParameters(parameters: parameters, encoding: JSONEncoding.default)
        case .iapNotifications(let payload):
            return .requestParameters(parameters: payload, encoding: JSONEncoding.default)

        default:
            return .requestPlain
        }
    }
    
    var headers: [String : String]? {
        var headParam : [String : String] = [:]
        let appLanguage = LanguageManager.currentLanguageCode()
        headParam["Accept-Language"] = appLanguage
        if case .ytAudio = self {
            headParam["Accept"] = "application/json"
        }
        if case .ytInfo = self {
            headParam["Accept"] = "application/json"
        }
        if requiresAuthorization, let authorizationValue = authorizationHeaderValue {
            headParam["Authorization"] = authorizationValue
        }
        // refresh 始终带当前 token（包括已过期的），让后端从 sub 解码用户身份
        if case .refreshAccessToken = self, let token = rawAccessToken {
            headParam["Authorization"] = "Bearer \(token)"
        }
        return headParam
    }
    
    var sampleData: Data {
        return Data()
    }

    private var requiresAuthorization: Bool {
        switch self {
        case .userInfo, .ytAudio, .ytInfo, .iapVerify, .iapStatus, .iapProducts, .iapRestore, .iapProductEntitlement, .deleteAccount, .currentUser:
            return true
        default:
            return false
        }
    }

    private var authorizationHeaderValue: String? {
        guard let token = rawAccessToken else { return nil }
        return "Bearer \(token)"
    }

    private var rawAccessToken: String? {
        let accessToken = UserManager.shared.currentUser?.access_token.isEmpty == false
            ? UserManager.shared.currentUser?.access_token
            : (PUserDefault.getVauleForKey(key: "access_token") as? String)

        guard let token = accessToken?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty else {
            return nil
        }

        return token
    }
}

// Stub for ContractAPIEndPoint
enum ContractAPIEndPoint: TargetType {
    case test
    
    var baseURL: URL { URL(string: "https://api.perapera.cc")! }
    var path: String { "" }
    var method: Moya.Method { .get }
    var task: Task { .requestPlain }
    var headers: [String : String]? { nil }
    var sampleData: Data { Data() }
}
