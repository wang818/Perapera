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
    @State private var showAuthAlert = false

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
            showAuthAlert = true
        }
        .alert("home_auth_error_title".localized(), isPresented: $showAuthAlert) {
            Button("common_cancel".localized(), role: .cancel) { }
            Button("home_go_settings".localized()) {
                selectedTab = 1
            }
        } message: {
            Text("home_auth_error_message".localized())
        }
        .onAppear {
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
}

#Preview {
    ContentView()
}
