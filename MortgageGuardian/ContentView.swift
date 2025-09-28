import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Dashboard")
                }
                .tag(0)

            DocumentsView()
                .tabItem {
                    Image(systemName: "doc.text.fill")
                    Text("Documents")
                }
                .tag(1)

            AnalysisView()
                .tabItem {
                    Image(systemName: "magnifyingglass.circle.fill")
                    Text("Analysis")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(3)
        }
    }
}

struct DashboardView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)

                Text("Mortgage Guardian")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Protecting your mortgage interests")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()
            }
            .padding()
            .navigationTitle("Dashboard")
        }
    }
}

struct DocumentsView: View {
    var body: some View {
        NavigationView {
            VStack {
                Image(systemName: "doc.text")
                    .font(.system(size: 40))
                    .foregroundColor(.gray)

                Text("No documents yet")
                    .font(.title2)
                    .foregroundColor(.secondary)

                Text("Upload your mortgage documents to get started")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .navigationTitle("Documents")
        }
    }
}

struct AnalysisView: View {
    var body: some View {
        NavigationView {
            VStack {
                Image(systemName: "magnifyingglass.circle")
                    .font(.system(size: 40))
                    .foregroundColor(.gray)

                Text("Analysis")
                    .font(.title2)
                    .foregroundColor(.secondary)

                Text("Upload documents to see analysis results")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .navigationTitle("Analysis")
        }
    }
}

struct SettingsView: View {
    var body: some View {
        NavigationView {
            List {
                Section("App") {
                    HStack {
                        Image(systemName: "info.circle")
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    ContentView()
}