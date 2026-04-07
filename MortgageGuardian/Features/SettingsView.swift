import SwiftUI

struct SettingsView: View {
    @AppStorage("defaultLoanTerm") private var defaultLoanTerm: Int = 30
    @AppStorage("defaultInterestRate") private var defaultInterestRate: Double = 6.5
    @AppStorage("useLocalCurrency") private var useLocalCurrency: Bool = false
    @AppStorage("includePMI") private var includePMI: Bool = true
    @AppStorage("includePropertyTax") private var includePropertyTax: Bool = true
    @AppStorage("includeHomeInsurance") private var includeHomeInsurance: Bool = true
    @State private var showingBackendConfig = false
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Picker("Default Loan Term", selection: $defaultLoanTerm) {
                        Text("15 Years").tag(15)
                        Text("20 Years").tag(20)
                        Text("30 Years").tag(30)
                    }
                    
                    HStack {
                        Text("Default Interest Rate")
                        Spacer()
                        TextField("Rate", value: $defaultInterestRate, format: .percent)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                } header: {
                    Text("Calculation Defaults")
                }
                
                Section {
                    Toggle("Use Local Currency", isOn: $useLocalCurrency)
                    Toggle("Include PMI", isOn: $includePMI)
                    Toggle("Include Property Tax", isOn: $includePropertyTax)
                    Toggle("Include Home Insurance", isOn: $includeHomeInsurance)
                } header: {
                    Text("Calculation Options")
                }
                
                Section {
                    NavigationRow(title: "Backend Connection", icon: "server.rack") {
                        showingBackendConfig = true
                    }

                    NavigationRow(title: "Rate History", icon: "chart.line.uptrend.xyaxis") {
                        // TODO: Implement rate history view
                    }

                    NavigationRow(title: "Export Data", icon: "square.and.arrow.up") {
                        // TODO: Implement export
                    }

                    NavigationRow(title: "Backup Settings", icon: "icloud.and.arrow.up") {
                        // TODO: Implement backup
                    }
                } header: {
                    Text("Data Management")
                }
                
                Section {
                    NavigationRow(title: "Help & Support", icon: "questionmark.circle") {
                        // TODO: Implement help view
                    }
                    
                    NavigationRow(title: "About", icon: "info.circle") {
                        // TODO: Implement about view
                    }
                } header: {
                    Text("Support")
                }
                
                Section {
                    VStack(alignment: .center, spacing: 8) {
                        Image("Logo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 60, height: 60)
                        
                        Text("Mortgage Guardian")
                            .font(.headline)
                        
                        Text("Version 1.0.0")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingBackendConfig) {
                // TODO: Backend connection configuration view
                Text("Backend: \(APIConfiguration.baseURL)")
                    .padding()
            }
        }
    }
}