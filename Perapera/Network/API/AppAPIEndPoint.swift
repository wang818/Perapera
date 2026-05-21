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
    case sendCaptcha(email: String)
    case login(email: String, captcha: String)
    case ytAudio(url: String)
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
        case .sendCaptcha : return "auth/sendCaptcha"
        case .login : return "auth/login"
        case .ytAudio: return "common/yt_audio"
            
        }
    }
    
    var method: Moya.Method {
        switch self {
        case .zendeskNotice: return .get
        case .supportLang: return .get
        case .sendCaptcha: return .get
        case .ytAudio: return .get
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
        case .ytAudio:
            return .requestPlain
        case .login(let email, let captcha):
            let params = ["email" : email, "captcha" : captcha]
            return .requestParameters(parameters: params, encoding: JSONEncoding.default)

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
        return headParam
    }
    
    var sampleData: Data {
        return Data()
    }
}

// Stub for ContractAPIEndPoint
enum ContractAPIEndPoint: TargetType {
    case test
    
    var baseURL: URL { URL(string: "https://api.perapera.com")! }
    var path: String { "" }
    var method: Moya.Method { .get }
    var task: Task { .requestPlain }
    var headers: [String : String]? { nil }
    var sampleData: Data { Data() }
}
