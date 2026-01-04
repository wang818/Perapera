//
//  ContentView.swift
//  Perapera
//
//  Created by apple on 2025/12/22.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("AppLanguage") private var appLanguage = "en"
    
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
    }
}

#Preview {
    ContentView()
}
