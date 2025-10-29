// MainTabView.swift
import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var documentManager: DocumentManager

    var body: some View {
        TabView {
            DocumentsView()
                .tabItem {
                    Image(systemName: "doc.text")
                    Text("Documents")
                }

            AnalysisView()
                .tabItem {
                    Image(systemName: "chart.bar.doc.horizontal")
                    Text("Analysis")
                }

            PlaidConnectionView()
                .tabItem {
                    Image(systemName: "building.columns")
                    Text("Accounts")
                }

            ProfileView()
                .tabItem {
                    Image(systemName: "person.circle")
                    Text("Profile")
                }
        }
        .accentColor(.blue)
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthManager())
        .environmentObject(DocumentManager())
}