//
//  ContentView.swift
//  Perapera
//
//  Created by apple on 2025/12/22.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }
            
            PodcastView()
                .tabItem {
                    Label("Podcast", systemImage: "mic")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

#Preview {
    ContentView()
}
