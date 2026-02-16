import SwiftUI

struct SettingsView: View {
    @StateObject private var authManager = AuthManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: ComicTheme.Dimensions.gutterWidth) {
                // Account section
                ComicPanelCard(titleBanner: "Account", bannerColor: ComicTheme.Colors.deepPurple) {
                    if authManager.isAuthenticated {
                        NavigationLink {
                            AccountView()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.title2.weight(.bold))
                                    .foregroundColor(ComicTheme.Colors.deepPurple)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(authManager.userEmail ?? "Signed in")
                                        .font(ComicTheme.Typography.comicButton(14))
                                        .foregroundColor(.primary)
                                    Text("Cloud sync enabled")
                                        .font(ComicTheme.Typography.speechBubble(12))
                                        .foregroundColor(ComicTheme.Colors.emeraldGreen)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    } else {
                        NavigationLink {
                            AuthView()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "person.crop.circle.badge.plus")
                                    .font(.title2.weight(.bold))
                                    .foregroundColor(ComicTheme.Colors.boldBlue)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Sign In / Sign Up")
                                        .font(ComicTheme.Typography.comicButton(14))
                                        .foregroundColor(.primary)
                                    Text("Create an account to sync dreams and AI content.")
                                        .font(ComicTheme.Typography.speechBubble(12))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Notifications section
                ComicPanelCard(titleBanner: "Notifications", bannerColor: ComicTheme.Colors.emeraldGreen) {
                    NavigationLink {
                        NotificationSettingsView()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "bell.badge.fill")
                                .font(.title3.weight(.bold))
                                .foregroundColor(ComicTheme.Colors.goldenYellow)
                            Text("Notification Settings")
                                .font(ComicTheme.Typography.comicButton(14))
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .halftoneBackground()
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AccountView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var showAvatarPicker = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(spacing: ComicTheme.Dimensions.gutterWidth) {
                // Profile card
                ComicPanelCard(titleBanner: "Profile", bannerColor: ComicTheme.Colors.deepPurple) {
                    HStack(spacing: 14) {
                        ProfilePictureView(size: 60, editable: true) {
                            showAvatarPicker = true
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(authManager.userEmail ?? "Signed in")
                                .font(ComicTheme.Typography.comicButton(14))
                            if authManager.isCloudEnabled {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption2)
                                    Text("Cloud sync enabled")
                                }
                                .font(ComicTheme.Typography.speechBubble(12))
                                .foregroundColor(ComicTheme.Colors.emeraldGreen)
                            }
                            if let profile = authManager.userProfile {
                                HStack(spacing: 4) {
                                    if let gender = profile.gender {
                                        Text(gender.capitalized)
                                    }
                                    if let age = profile.age {
                                        Text("· \(age)")
                                    }
                                }
                                .font(ComicTheme.Typography.speechBubble(12))
                                .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                    }
                }

                // Avatar description
                if authManager.avatarDescription != nil {
                    ComicPanelCard(titleBanner: "Dream Character", bannerColor: ComicTheme.Colors.hotPink) {
                        HStack(spacing: 12) {
                            Image(systemName: "person.text.rectangle")
                                .font(.title3.weight(.bold))
                                .foregroundColor(ComicTheme.Colors.hotPink)
                            Text(authManager.avatarDescription ?? "")
                                .font(ComicTheme.Typography.speechBubble(13))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Sign out
                Button(role: .destructive) {
                    authManager.logout()
                } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                }
                .buttonStyle(.comicDestructive)
            }
            .padding()
        }
        .halftoneBackground()
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAvatarPicker) {
            AvatarPickerView()
        }
    }
}
