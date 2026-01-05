//
//  EXTracking.swift
//  Perapera
//
//  Created by Perapera on 2024.
//

import Foundation

enum EXTrackingEvent: String {
    case httpTrack = "httpTrack"
    case httpTrackLow = "httpTrackLow"
}

class EXTracking {
    static let shared = EXTracking()
    
    func track(event: EXTrackingEvent, info: [String: Any]) {
        print("[EXTracking] Event: \(event.rawValue), Info: \(info)")
    }
}
