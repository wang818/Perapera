import SwiftUI

struct PodcastView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Image(systemName: "mic.fill")
                    .resizable()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.purple)
                Text("Podcast")
                    .font(.largeTitle)
                    .padding()
            }
            .navigationTitle("Podcast")
        }
    }
}

#Preview {
    PodcastView()
}
