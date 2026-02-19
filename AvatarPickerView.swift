import SwiftUI
import PhotosUI

/// Avatar selection flow: Memoji sticker, Photo Library, Camera, or Remove
struct AvatarPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
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
            ScrollView {
                VStack(spacing: ComicTheme.Dimensions.gutterWidth) {
                    // Current avatar
                    ComicPanelCard(titleBanner: L("Current Avatar"), bannerColor: ComicTheme.Colors.deepPurple) {
                        HStack {
                            Spacer()
                            ProfilePictureView(size: 120)
                            Spacer()
                        }
                    }

                    if let preview = previewImage {
                        // Preview selected image
                        ComicPanelCard(titleBanner: L("New Photo"), bannerColor: ComicTheme.Colors.emeraldGreen) {
                            VStack(spacing: 16) {
                                HStack {
                                    Spacer()
                                    Image(uiImage: preview)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 120, height: 120)
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle()
                                                .stroke(
                                                    ComicTheme.panelBorderColor(colorScheme),
                                                    lineWidth: ComicTheme.Dimensions.panelBorderWidth
                                                )
                                        )
                                    Spacer()
                                }

                                if isUploading {
                                    ProgressView(L("Uploading..."))
                                        .tint(ComicTheme.Colors.boldBlue)
                                } else {
                                    Button {
                                        useSelectedImage()
                                    } label: {
                                        Label(L("Use This Photo"), systemImage: "checkmark.circle.fill")
                                    }
                                    .buttonStyle(.comicPrimary(color: ComicTheme.Colors.emeraldGreen))

                                    Button {
                                        previewImage = nil
                                        selectedPhotoItem = nil
                                    } label: {
                                        Label(L("Cancel"), systemImage: "xmark.circle")
                                    }
                                    .buttonStyle(.comicSecondary(color: ComicTheme.Colors.crimsonRed))
                                }
                            }
                        }
                    } else {
                        // Action buttons
                        ComicPanelCard(titleBanner: L("Choose Avatar"), bannerColor: ComicTheme.Colors.boldBlue) {
                            VStack(spacing: 12) {
                                Button {
                                    showMemojiBridge = true
                                } label: {
                                    Label(L("Use Memoji"), systemImage: "face.smiling")
                                }
                                .buttonStyle(.comicPrimary(color: ComicTheme.Colors.boldBlue))

                                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                    Label(L("Choose Photo"), systemImage: "photo.on.rectangle")
                                        .frame(maxWidth: .infinity)
                                        .font(ComicTheme.Typography.comicButton(16))
                                        .padding(.vertical, 12)
                                        .background(ComicTheme.Semantic.cardSurface(colorScheme))
                                        .foregroundColor(ComicTheme.Colors.boldBlue)
                                        .clipShape(RoundedRectangle(cornerRadius: ComicTheme.Dimensions.buttonCornerRadius))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: ComicTheme.Dimensions.buttonCornerRadius)
                                                .stroke(ComicTheme.Colors.boldBlue, lineWidth: 2.5)
                                        )
                                }

                                Button {
                                    showCamera = true
                                } label: {
                                    Label(L("Take Photo"), systemImage: "camera")
                                }
                                .buttonStyle(.comicSecondary(color: ComicTheme.Colors.boldBlue))

                                if authManager.avatarImageData != nil {
                                    Button(role: .destructive) {
                                        removeAvatar()
                                    } label: {
                                        Label(L("Remove Avatar"), systemImage: "trash")
                                    }
                                    .buttonStyle(.comicDestructive)
                                }
                            }
                        }
                    }

                    // Privacy notice
                    ComicPanelCard(titleBanner: L("Privacy"), bannerColor: ComicTheme.Colors.goldenYellow) {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "lock.shield")
                                .font(.body.weight(.bold))
                                .foregroundColor(ComicTheme.Colors.goldenYellow)
                                .frame(width: 24)
                            Text(L("Your photo creates a text description of your appearance. The photo itself is not shared with AI services."))
                                .font(ComicTheme.Typography.speechBubble(12))
                                .foregroundColor(.secondary)
                        }
                    }

                    if let error = errorMessage {
                        Text(error)
                            .font(ComicTheme.Typography.speechBubble(12))
                            .foregroundColor(ComicTheme.Colors.crimsonRed)
                            .padding(.horizontal)
                    }
                }
                .padding()
            }
            .halftoneBackground()
            .navigationTitle(L("Profile Picture"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("Cancel")) {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showMemojiBridge) {
                NavigationView {
                    MemojiTextViewWrapper(onSave: { image in
                        previewImage = image
                        showMemojiBridge = false
                    })
                    .navigationTitle(L("Memoji"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(L("Cancel")) {
                                showMemojiBridge = false
                            }
                        }
                    }
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

// MARK: - Memoji UITextView (renders sticker images inline)

struct MemojiTextViewWrapper: UIViewControllerRepresentable {
    let onSave: (UIImage) -> Void

    func makeUIViewController(context: Context) -> MemojiTextViewController {
        let vc = MemojiTextViewController()
        vc.onSave = onSave
        return vc
    }

    func updateUIViewController(_ uiViewController: MemojiTextViewController, context: Context) {
        uiViewController.onSave = onSave
    }
}

class MemojiTextViewController: UIViewController {
    var onSave: ((UIImage) -> Void)?
    private let textView = UITextView()
    private let instructionLabel = UILabel()
    private let previewImageView = UIImageView()
    private let useButton = UIButton(type: .system)
    private let pasteButton = UIButton(type: .system)
    private var pasteboardObserver: Any?
    private var clipboardTimer: Timer?
    private var lastPasteboardChangeCount = UIPasteboard.general.changeCount
    private var capturedImage: UIImage?

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        // Instruction label
        instructionLabel.numberOfLines = 0
        instructionLabel.textAlignment = .center
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        let steps = [
            L("Tap the area below to open the keyboard"),
            L("Tap") + " 🌐 " + L("to switch to emoji keyboard"),
            L("Swipe to find Memoji stickers and tap one"),
        ]
        let text = steps.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
        instructionLabel.text = text
        instructionLabel.font = .preferredFont(forTextStyle: .subheadline)
        instructionLabel.textColor = .secondaryLabel
        view.addSubview(instructionLabel)

        // Text view (receives sticker paste from keyboard)
        textView.font = .systemFont(ofSize: 48)
        textView.textAlignment = .center
        textView.backgroundColor = .secondarySystemBackground
        textView.layer.cornerRadius = 12
        textView.clipsToBounds = true
        textView.allowsEditingTextAttributes = true
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.delegate = self
        view.addSubview(textView)

        // Preview image (shown when a Memoji is captured)
        previewImageView.contentMode = .scaleAspectFit
        previewImageView.layer.cornerRadius = 60
        previewImageView.clipsToBounds = true
        previewImageView.layer.borderWidth = 3
        previewImageView.layer.borderColor = UIColor.systemBlue.cgColor
        previewImageView.translatesAutoresizingMaskIntoConstraints = false
        previewImageView.isHidden = true
        view.addSubview(previewImageView)

        // "Use This Memoji" button (shown after capture)
        var useConfig = UIButton.Configuration.filled()
        useConfig.title = L("Use This Memoji")
        useConfig.image = UIImage(systemName: "checkmark.circle.fill")
        useConfig.imagePadding = 8
        useConfig.baseBackgroundColor = .systemGreen
        useButton.configuration = useConfig
        useButton.addTarget(self, action: #selector(useTapped), for: .touchUpInside)
        useButton.translatesAutoresizingMaskIntoConstraints = false
        useButton.isHidden = true
        view.addSubview(useButton)

        // "Paste from Clipboard" fallback
        var pasteConfig = UIButton.Configuration.tinted()
        pasteConfig.title = L("Or paste copied Memoji from clipboard")
        pasteConfig.image = UIImage(systemName: "doc.on.clipboard")
        pasteConfig.imagePadding = 8
        pasteConfig.baseForegroundColor = .secondaryLabel
        pasteButton.configuration = pasteConfig
        pasteButton.addTarget(self, action: #selector(pasteTapped), for: .touchUpInside)
        pasteButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pasteButton)

        NSLayoutConstraint.activate([
            instructionLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            instructionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            instructionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            textView.topAnchor.constraint(equalTo: instructionLabel.bottomAnchor, constant: 16),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            textView.heightAnchor.constraint(equalToConstant: 120),

            previewImageView.topAnchor.constraint(equalTo: textView.bottomAnchor, constant: 16),
            previewImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            previewImageView.widthAnchor.constraint(equalToConstant: 120),
            previewImageView.heightAnchor.constraint(equalToConstant: 120),

            useButton.topAnchor.constraint(equalTo: previewImageView.bottomAnchor, constant: 16),
            useButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            useButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            useButton.heightAnchor.constraint(equalToConstant: 50),

            pasteButton.topAnchor.constraint(equalTo: useButton.bottomAnchor, constant: 12),
            pasteButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])

        // Poll clipboard every 0.5s (UIPasteboard.changedNotification is unreliable for stickers)
        lastPasteboardChangeCount = UIPasteboard.general.changeCount
        clipboardTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkClipboardForNewImage()
        }
    }

    deinit {
        clipboardTimer?.invalidate()
        if let observer = pasteboardObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        textView.becomeFirstResponder()
    }

    private func checkClipboardForNewImage() {
        let currentCount = UIPasteboard.general.changeCount
        guard currentCount != lastPasteboardChangeCount else { return }
        lastPasteboardChangeCount = currentCount

        if let image = UIPasteboard.general.image {
            showCapturedImage(image)
        }
    }

    private func showCapturedImage(_ image: UIImage) {
        capturedImage = image
        previewImageView.image = image
        previewImageView.isHidden = false
        useButton.isHidden = false

        // Dismiss keyboard to make space for preview + button
        textView.resignFirstResponder()
    }

    @objc private func useTapped() {
        guard let image = capturedImage else { return }
        let callback = onSave
        DispatchQueue.main.async {
            callback?(image)
        }
    }

    @objc private func pasteTapped() {
        if let image = UIPasteboard.general.image {
            showCapturedImage(image)
        }
    }
}

extension MemojiTextViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        // Check if sticker was inserted as NSTextAttachment
        let attrText = textView.attributedText ?? NSAttributedString()
        attrText.enumerateAttribute(.attachment, in: NSRange(location: 0, length: attrText.length)) { value, _, stop in
            if let attachment = value as? NSTextAttachment,
               let image = attachment.image ?? attachment.image(forBounds: attachment.bounds, textContainer: nil, characterIndex: 0) {
                self.showCapturedImage(image)
                stop.pointee = true
            }
        }
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
