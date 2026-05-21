//
//  PeraperaApp.swift
//  Perapera
//
//  Created by apple on 2025/12/22.
//

import SwiftUI

@main
struct PeraperaApp: App {
    init() {
        // 启动时设置本地开发凭证（DEBUG 构建生效）
        #if DEBUG
        COSConfig.setupLocalCredentials()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
