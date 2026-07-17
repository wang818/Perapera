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
        AliyunConfig.setupLocalCredentials()
        #endif

        // 提前初始化内购状态，保证设置页和购买页打开时可以直接拿到本地权益。
        _ = PurchaseManager.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
