import SwiftUI

struct NewDreamView: View {
    @EnvironmentObject var store: DreamStore
    @Environment(\.dismiss) var dismiss

    @State private var dreamText = ""

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    Text("What did you dream?")
                        .font(ComicTheme.Typography.speechBubble())
                        .speechBubble()
                        .padding(.top)

                    ComicPanelCard(bannerColor: ComicTheme.Colors.deepPurple) {
                        ZStack(alignment: .topLeading) {
                            if dreamText.isEmpty {
                                Text("Describe your dream or nightmare...")
                                    .foregroundColor(.secondary)
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                            }

                            TextEditor(text: $dreamText)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 200)
                        }
                    }

                    Button {
                        let dream = Dream(originalText: dreamText)
                        store.addDream(dream)
                        dismiss()
                    } label: {
                        Label("Save Dream", systemImage: "checkmark.circle.fill")
                    }
                    .buttonStyle(.comicPrimary(color: ComicTheme.Colors.emeraldGreen))
                    .disabled(dreamText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
            }
            .halftoneBackground()
            .navigationTitle("New Dream")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(ComicTheme.Colors.crimsonRed)
                    .fontWeight(.bold)
                }
            }
        }
    }
}
