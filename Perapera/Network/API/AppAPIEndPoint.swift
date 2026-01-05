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
}

extension AppAPIEndPoint: TargetType {
    var baseURL: URL {
        return URL(string: "http://www.perapera.cc/api/v1/")!
    }
    
    var path: String {
        switch self {
        case .test: return "/test"
        case .userInfo: return "/user/info"
        case .zendeskNotice: return ""
        case .supportLang: return "common/support_lang"
            
        }
    }
    
    var method: Moya.Method {
        switch self {
        case .zendeskNotice: return .get
        case .supportLang: return .get
        default: return .post
        }
    }

    
    var task: Task {
        switch self {
        case .zendeskNotice(let page, let pagesize):
            let params = ["page": page, "pagesize": pagesize]
            return .requestParameters(parameters: params, encoding: JSONEncoding.default)
        default:
            return .requestPlain
        }
    }
    
    var headers: [String : String]? {
        return nil
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
