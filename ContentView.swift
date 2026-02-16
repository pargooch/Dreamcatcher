import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: DreamStore
    @State private var showNewDream = false
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: ComicTheme.Dimensions.gutterWidth) {
                    if store.dreams.isEmpty {
                        emptyState
                    } else {
                        ForEach(store.dreams) { dream in
                            NavigationLink {
                                DreamDetailView(dream: dream)
                            } label: {
                                DreamRowView(dream: dream)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    NotificationManager.shared.cancelDreamNotification(for: dream.id)
                                    store.deleteDream(dream)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .halftoneBackground()
            .navigationTitle("Dreamcatcher")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(ComicTheme.Colors.deepPurple)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showNewDream = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(ComicTheme.Colors.boldBlue)
                    }
                }
            }
            .sheet(isPresented: $showNewDream) {
                NewDreamView()
            }
            .sheet(isPresented: $showSettings) {
                NavigationView {
                    SettingsView()
                }
            }
        }
    }

    private var emptyState: some View {
        ComicPanelCard(titleBanner: "Welcome, Dreamer!", bannerColor: ComicTheme.Colors.deepPurple) {
            VStack(spacing: 16) {
                SoundEffectText(text: "DREAM ON!", fillColor: ComicTheme.Colors.goldenYellow, fontSize: 42)

                Text("Record your first dream to begin your comic journey!")
                    .font(ComicTheme.Typography.speechBubble())
                    .multilineTextAlignment(.center)
                    .speechBubble()

                Button {
                    showNewDream = true
                } label: {
                    Label("Capture a Dream", systemImage: "moon.stars.fill")
                }
                .buttonStyle(.comicPrimary(color: ComicTheme.Colors.deepPurple))
            }
        }
        .padding(.top, 40)
    }
}

struct DreamRowView: View {
    let dream: Dream
    @Environment(\.colorScheme) private var colorScheme
    @State private var appeared = false

    private var accentColor: Color {
        if dream.hasComicPages { return ComicTheme.Colors.goldenYellow }
        if dream.rewrittenText != nil { return ComicTheme.Colors.boldBlue }
        return ComicTheme.Colors.deepPurple
    }

    var body: some View {
        ComicPanelCard {
            HStack(spacing: 12) {
                // Thumbnail if comic pages or images exist
                if let firstPage = dream.sortedComicPages.first, let uiImage = firstPage.uiImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(ComicTheme.panelBorderColor(colorScheme), lineWidth: 1.5)
                        )
                } else if let firstImage = dream.sortedImages.first, let uiImage = firstImage.uiImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(ComicTheme.panelBorderColor(colorScheme), lineWidth: 1.5)
                        )
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(dream.originalText)
                        .lineLimit(2)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)

                    HStack(spacing: 6) {
                        // Date badge
                        Text(dream.date, style: .date)
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(accentColor.opacity(0.15))
                            .foregroundColor(accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 4))

                        Spacer()

                        if dream.rewrittenText != nil {
                            Image(systemName: "sparkles")
                                .font(.caption.weight(.bold))
                                .foregroundColor(ComicTheme.Colors.goldenYellow)
                        }

                        if dream.hasComicPages || dream.hasImages {
                            Image(systemName: "book.pages.fill")
                                .font(.caption.weight(.bold))
                                .foregroundColor(ComicTheme.Colors.boldBlue)
                        }
                    }
                }
            }
        }
        .scaleEffect(appeared ? 1.0 : 0.92)
        .opacity(appeared ? 1.0 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                appeared = true
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(DreamStore())
}
