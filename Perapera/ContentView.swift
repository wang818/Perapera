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
    
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("tab_home".localized(), systemImage: "house")
                }
            
            PodcastView()
                .tabItem {
                    Label("tab_podcast".localized(), systemImage: "mic")
                }
            
            SettingsView()
                .tabItem {
                    Label("tab_settings".localized(), systemImage: "gear")
                }
        }
        .id(appLanguage)
        .preferredColorScheme(appTheme.colorScheme)
    }
}

#Preview {
    ContentView()
}
