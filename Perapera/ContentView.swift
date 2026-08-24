//
//  ContentView.swift
//  Perapera
//
//  Created by apple on 2025/12/22.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("AppLanguage") private var appLanguage = "en"
    @AppStorage("AppTheme") private var appTheme: AppTheme = .system
    @State private var selectedTab = 0
    @State private var showReauthLogin = false
    @State private var showAIConsent = false

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("tab_home".localized(), systemImage: selectedTab == 0 ? "house.fill" : "house")
                }
                .tag(0)

            SettingsView()
                .tabItem {
                    Label("tab_settings".localized(), systemImage: selectedTab == 1 ? "gearshape.fill" : "gearshape")
                }
                .tag(1)
        }
        .tint(Color.Ex.main)
        .id(appLanguage)
        .preferredColorScheme(appTheme.colorScheme)
        .onReceive(NotificationCenter.default.publisher(for: .peraperaAPIUnauthorized)) { _ in
            // refresh 失败 / token 彻底过期：清掉旧登录态 + 全屏拉起登录页
            UserManager.shared.logout()
            showReauthLogin = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .peraperaRequestShowLogin)) { _ in
            // 业务层（播放页等）请求弹出 LoginView
            showReauthLogin = true
        }
        .fullScreenCover(isPresented: $showReauthLogin) {
            LoginView()
        }
        .fullScreenCover(isPresented: $showAIConsent) {
            AIConsentView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .peraperaRequestAIConsent)) { _ in
            // + 按钮等业务入口请求弹授权弹窗时，仅在已登录且当前账户未同意时弹出
            ensureAIConsentIfNeeded()
        }
        .onReceive(UserManager.shared.$currentUser) { _ in
            // 切换账户（含登录 / 登出后重新登录）后，按新账户重新判定是否需要授权
            ensureAIConsentIfNeeded()
        }
        .onAppear {
            // 首次启动 / 当前账户未授权时弹出 AI 数据共享授权弹窗
            ensureAIConsentIfNeeded()

            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor.Ex.homepagebg

            // 选中状态
            appearance.stackedLayoutAppearance.selected.iconColor = UIColor.Ex.main
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
                .foregroundColor: UIColor.Ex.main,
                .font: UIFont.systemFont(ofSize: 10, weight: .semibold)
            ]

            // 未选中状态
            appearance.stackedLayoutAppearance.normal.iconColor = UIColor.Ex.text3
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
                .foregroundColor: UIColor.Ex.text3,
                .font: UIFont.systemFont(ofSize: 10, weight: .regular)
            ]

            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }

    /// 已登录且当前账户尚未同意 AI / 第三方数据共享时，弹出授权弹窗。
    /// 切换账户后由 onReceive(currentUser) 重新触发；+ 按钮等业务入口也可通过通知触发。
    /// 未登录时不弹（由 + 按钮等入口引导用户先去登录）。
    private func ensureAIConsentIfNeeded() {
        guard UserManager.shared.isLoggedIn,
              !UserManager.shared.hasAIDataSharingConsent else { return }
        DispatchQueue.main.async {
            self.showAIConsent = true
        }
    }
}

#Preview {
    ContentView()
}
