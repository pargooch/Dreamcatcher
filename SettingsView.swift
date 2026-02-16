import SwiftUI

struct SettingsView: View {
    @StateObject private var authManager = AuthManager.shared

    var body: some View {
        List {
            Section {
                if authManager.isAuthenticated {
                    NavigationLink {
                        AccountView()
                    } label: {
                        HStack {
                            Image(systemName: "person.crop.circle.fill")
                                .foregroundColor(.accentColor)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(authManager.userEmail ?? "Signed in")
                                    .font(.subheadline)
                                Text("Cloud sync enabled")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    NavigationLink {
                        AuthView()
                    } label: {
                        HStack {
                            Image(systemName: "person.crop.circle.badge.plus")
                                .foregroundColor(.accentColor)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Sign In / Sign Up")
                                    .font(.subheadline)
                                Text("Create an account to sync dreams and AI content.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } header: {
                Text("Account")
            }

            NavigationLink {
                NotificationSettingsView()
            } label: {
                HStack {
                    Image(systemName: "bell.badge")
                        .foregroundColor(.accentColor)
                    Text("Notifications")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AccountView: View {
    @StateObject private var authManager = AuthManager.shared

    var body: some View {
        Form {
            Section {
                HStack {
                    Image(systemName: "person.crop.circle.fill")
                        .foregroundColor(.accentColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(authManager.userEmail ?? "Signed in")
                            .font(.subheadline)
                        if authManager.isCloudEnabled {
                            Text("Cloud sync enabled")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                }
            }

            Section {
                Button(role: .destructive) {
                    authManager.logout()
                } label: {
                    HStack {
                        Spacer()
                        Text("Sign Out")
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
    }
}
