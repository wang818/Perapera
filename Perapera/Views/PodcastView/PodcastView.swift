import SwiftUI

struct PodcastView: View {
    var body: some View {
        NavigationView {
            VStack {
                Image(systemName: "mic.fill")
                    .resizable()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.purple)
                Text("podcast_title".localized())
                    .font(.largeTitle)
                    .padding()
            }
            .navigationTitle("podcast_title".localized())
        }
    }
}

#Preview {
    PodcastView()
}
