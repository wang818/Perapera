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

        // 启动时主动刷新 token：3 天有效期内每次启动都续期
        if UserManager.shared.isLoggedIn {
            _ = AuthRefreshService.shared.refreshIfNeeded()
                .subscribe(onSuccess: { _ in
                    print("✅ 启动刷新 token 成功")
                }, onFailure: { _ in
                    // refresh 失败由 AuthRefreshRetrier 在 401 时主动广播，这里不重复处理
                })
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
