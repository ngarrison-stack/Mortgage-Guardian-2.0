// ProfileView.swift
import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var documentManager: DocumentManager
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header
                    profileHeader

                    // Account Statistics
                    statisticsSection

                    // Settings and Options
                    settingsSection

                    // Sign Out Button
                    signOutButton
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Profile")
        }
    }

    // MARK: - Profile Header
    private var profileHeader: some View {
        VStack(spacing: 16) {
            // Profile Image
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [.blue, .purple]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 100, height: 100)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                )

            // User Info
            VStack(spacing: 4) {
                Text(authManager.user?.firstName ?? "User")
                    .font(.title2)
                    .fontWeight(.bold)

                Text(authManager.user?.primaryEmailAddress?.emailAddress ?? "")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - Statistics Section
    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Account Overview")
                .font(.headline)
                .padding(.horizontal)

            HStack(spacing: 16) {
                StatCard(
                    title: "Documents",
                    value: "\(documentManager.documents.count)",
                    icon: "doc.text.fill",
                    color: .blue
                )

                StatCard(
                    title: "Analyses",
                    value: "0",
                    icon: "chart.bar.fill",
                    color: .green
                )
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Settings Section
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings")
                .font(.headline)
                .padding(.horizontal)

            VStack(spacing: 0) {
                SettingsRow(
                    icon: "bell.fill",
                    title: "Notifications",
                    color: .orange
                )

                Divider()
                    .padding(.leading, 56)

                SettingsRow(
                    icon: "lock.fill",
                    title: "Privacy & Security",
                    color: .blue
                )

                Divider()
                    .padding(.leading, 56)

                SettingsRow(
                    icon: "doc.text.fill",
                    title: "Terms & Conditions",
                    color: .gray
                )

                Divider()
                    .padding(.leading, 56)

                SettingsRow(
                    icon: "questionmark.circle.fill",
                    title: "Help & Support",
                    color: .purple
                )

                Divider()
                    .padding(.leading, 56)

                SettingsRow(
                    icon: "info.circle.fill",
                    title: "About",
                    color: .cyan
                )
            }
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }

    // MARK: - Sign Out Button
    private var signOutButton: some View {
        Button(action: {
            Task {
                try? await authManager.signOut()
            }
        }) {
            HStack {
                Image(systemName: "arrow.right.square.fill")
                    .font(.title3)
                Text("Sign Out")
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red)
            .cornerRadius(12)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        Button(action: {
            // TODO: Implement navigation
        }) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(color)
                    .cornerRadius(8)

                Text(title)
                    .foregroundColor(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
    }
}

// MARK: - Preview

#Preview {
    ProfileView()
        .environmentObject(AuthManager())
        .environmentObject(DocumentManager())
}
