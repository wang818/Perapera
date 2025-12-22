import SwiftUI

struct HomeView: View {
    // Sample data
    let items = Array(1...20).map { "Item \($0)" }

    var body: some View {
        NavigationStack {
            List(items, id: \.self) { item in
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundColor(.blue)
                    Text(item)
                }
                .frame(height: 60)
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Perapera")
        }
    }
}

#Preview {
    HomeView()
}
