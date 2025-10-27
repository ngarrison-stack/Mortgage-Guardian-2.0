import SwiftUI

struct CalculatorMainTabView: View {
    @State private var appState = AppState()

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            CalculatorView()
                .tabItem {
                    Label("Calculator", systemImage: "calculator")
                }
                .tag(Tab.calculator)

            Text("Saved Scenarios")  // TODO: Implement ScenariosView
                .tabItem {
                    Label("Scenarios", systemImage: "list.bullet")
                }
                .tag(Tab.scenarios)

            Text("Settings")  // TODO: Implement SettingsView
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(Tab.settings)
        }
    }
}
