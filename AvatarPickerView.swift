import SwiftUI
import PhotosUI

/// Avatar selection flow: Memoji sticker, Photo Library, Camera, or Remove
struct AvatarPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authManager = AuthManager.shared

    @State private var showMemojiBridge = false
    @State private var showPhotoPicker = false
    @State private var showCamera = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var previewImage: UIImage?
    @State private var isUploading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Current avatar preview
                ProfilePictureView(size: 120)
                    .padding(.top, 20)

                if let preview = previewImage {
                    // Preview selected image
                    VStack(spacing: 16) {
                        Image(uiImage: preview)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(ComicTheme.Colors.boldBlue, lineWidth: 3))

                        if isUploading {
                            ProgressView("Uploading...")
                                .tint(ComicTheme.Colors.boldBlue)
                        } else {
                            Button {
                                useSelectedImage()
                            } label: {
                                Label("Use This Photo", systemImage: "checkmark.circle.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(ComicTheme.Colors.boldBlue)
                        }
                    }
                } else {
                    // Action buttons
                    VStack(spacing: 12) {
                        Button {
                            showMemojiBridge = true
                        } label: {
                            Label("Use Memoji", systemImage: "face.smiling")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(ComicTheme.Colors.boldBlue)

                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            Label("Choose Photo", systemImage: "photo.on.rectangle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(ComicTheme.Colors.boldBlue)

                        Button {
                            showCamera = true
                        } label: {
                            Label("Take Photo", systemImage: "camera")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(ComicTheme.Colors.boldBlue)

                        if authManager.avatarImageData != nil {
                            Button(role: .destructive) {
                                removeAvatar()
                            } label: {
                                Label("Remove Avatar", systemImage: "trash")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }

                // Privacy notice
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lock.shield")
                        .foregroundColor(.secondary)
                    Text("Your photo creates a text description of your appearance. The photo itself is not shared with AI services.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(ComicTheme.Colors.crimsonRed)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Profile Picture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showMemojiBridge) {
                MemojiBridgeView { image in
                    previewImage = image
                    showMemojiBridge = false
                }
            }
            .sheet(isPresented: $showCamera) {
                CameraPickerView { image in
                    previewImage = image
                    showCamera = false
                }
            }
            .onChange(of: selectedPhotoItem) {
                loadSelectedPhoto()
            }
        }
    }

    private func loadSelectedPhoto() {
        guard let item = selectedPhotoItem else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    previewImage = image
                }
            }
        }
    }

    private func useSelectedImage() {
        guard let image = previewImage else { return }

        // Resize to 512x512 max
        let resized = resizeImage(image, maxSize: 512)
        guard let pngData = resized.pngData() else { return }

        isUploading = true
        errorMessage = nil

        Task {
            if AuthManager.shared.isAuthenticated {
                do {
                    let response = try await BackendService.shared.uploadAvatar(imageData: pngData)
                    await MainActor.run {
                        authManager.setAvatar(imageData: pngData, description: response.avatar_description)
                        isUploading = false
                        dismiss()
                    }
                } catch {
                    await MainActor.run {
                        // Store locally even if upload fails
                        authManager.setAvatar(imageData: pngData, description: "User avatar")
                        isUploading = false
                        dismiss()
                    }
                }
            } else {
                // Store locally only
                await MainActor.run {
                    authManager.setAvatar(imageData: pngData, description: "User avatar")
                    isUploading = false
                    dismiss()
                }
            }
        }
    }

    private func removeAvatar() {
        Task {
            if AuthManager.shared.isAuthenticated {
                try? await BackendService.shared.deleteAvatar()
            }
            await MainActor.run {
                authManager.clearAvatar()
                dismiss()
            }
        }
    }

    private func resizeImage(_ image: UIImage, maxSize: CGFloat) -> UIImage {
        let size = image.size
        let ratio = min(maxSize / size.width, maxSize / size.height)
        if ratio >= 1 { return image }

        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

// MARK: - Memoji Bridge View

struct MemojiBridgeView: View {
    let onImageCaptured: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "face.smiling")
                    .font(.system(size: 60))
                    .foregroundColor(ComicTheme.Colors.boldBlue)

                Text("Paste Your Memoji")
                    .font(ComicTheme.Typography.dreamTitle(24))

                Text("1. Tap the text field below\n2. Switch to the Memoji keyboard\n3. Tap your favorite Memoji sticker")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                PasteableTextFieldWrapper { image in
                    onImageCaptured(image)
                }
                .frame(height: 60)
                .padding(.horizontal, 40)

                Spacer()
            }
            .navigationTitle("Memoji")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Pasteable Text Field (captures Memoji sticker images)

struct PasteableTextFieldWrapper: UIViewRepresentable {
    let onImagePasted: (UIImage) -> Void

    func makeUIView(context: Context) -> PasteableTextField {
        let textField = PasteableTextField()
        textField.onImagePasted = onImagePasted
        textField.placeholder = "Tap here, then paste Memoji..."
        textField.textAlignment = .center
        textField.borderStyle = .roundedRect
        textField.font = .systemFont(ofSize: 16)
        return textField
    }

    func updateUIView(_ uiView: PasteableTextField, context: Context) {}
}

class PasteableTextField: UITextField {
    var onImagePasted: ((UIImage) -> Void)?

    override func paste(_ sender: Any?) {
        if let image = UIPasteboard.general.image {
            onImagePasted?(image)
            return
        }
        super.paste(sender)
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(paste(_:)) {
            return true
        }
        return super.canPerformAction(action, withSender: sender)
    }
}

// MARK: - Camera Picker

struct CameraPickerView: UIViewControllerRepresentable {
    let onImageCaptured: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImageCaptured: onImageCaptured, dismiss: dismiss)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImageCaptured: (UIImage) -> Void
        let dismiss: DismissAction

        init(onImageCaptured: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onImageCaptured = onImageCaptured
            self.dismiss = dismiss
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onImageCaptured(image)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}
