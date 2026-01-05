//
//  XHUDManager.swift
//  Perapera
//
//  Created by Perapera on 2024.
//

import Foundation

class XHUDManager {
    static let sharedInstance = XHUDManager()
    
    func loading() {
        print("[XHUDManager] Loading...")
    }
    
    func dismissWithDelay(completion: @escaping () -> Void) {
        print("[XHUDManager] Dismiss")
        completion()
    }
    
    func noloading() {
        print("[XHUDManager] No Loading")
    }
}
