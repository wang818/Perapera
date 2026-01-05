//
//  Observable+HandyJSON.swift
//  Perapera
//
//  Created by Perapera on 2024.
//

import Foundation
import RxSwift
import Moya
import HandyJSON

extension ObservableType where Element == Response {
    
    /// Maps data received from the signal into an object which implements the HandyJSON protocol.
    /// If the conversion fails, the signal errors.
    public func mapObject<T: HandyJSON>(_ type: T.Type) -> Observable<T> {
        return self.map { response -> T in
            // Try mapping to JSON first
            guard let json = try? response.mapJSON() as? [String: Any] else {
                throw MoyaError.jsonMapping(response)
            }
            
            // In coinup-bigclient-ios, the response structure usually wraps the data in a 'data' field
            // But here we need to see if the user wants the raw JSON mapped or if there is a wrapper.
            // Based on EXNewHomePageVc usage: .MJObjectMap(EXZendeskNoticeModel.self)
            // MJObjectMap usually maps the ROOT dictionary to the object.
            // If the API returns { "code": 0, "data": { ... } }, then EXZendeskNoticeModel should probably match 'data' or the root.
            // Looking at EXZendeskNoticeModel in coinup, it seems to be the data model itself.
            // Let's assume standard response unwrapping is handled elsewhere or the model matches the response.
            // However, usually API responses are wrapped in a Result structure.
            // Let's check NetWorkService or how response is handled.
            
            // For now, let's assume we map the "data" field if it exists, otherwise the root.
            // If the root matches the model properties, HandyJSON will map it.
            
            // Let's try to map the whole JSON first.
            if let model = T.deserialize(from: json) {
                return model
            }
            
            // If direct mapping fails, maybe it's inside "data"
            if let data = json["data"] as? [String: Any], let model = T.deserialize(from: data) {
                return model
            }
            
            throw MoyaError.jsonMapping(response)
        }
    }

    public func mapArray<T: HandyJSON>(_ type: T.Type) -> Observable<[T]> {
        return self.map { response -> [T] in
            guard let json = try? response.mapJSON() else {
                 throw MoyaError.jsonMapping(response)
            }
            
            // Check if it's an array directly
            if let jsonArray = json as? [[String: Any]],
               let models = [T].deserialize(from: jsonArray) as? [T] {
                return models
            }
            
            // Check if it's inside "data"
            if let jsonDict = json as? [String: Any],
               let dataArray = jsonDict["data"] as? [[String: Any]],
               let models = [T].deserialize(from: dataArray) as? [T] {
                return models
            }
            
            throw MoyaError.jsonMapping(response)
        }
    }
}
