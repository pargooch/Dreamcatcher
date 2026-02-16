import SwiftUI

/// Full-screen comic page viewer with pinch-to-zoom and page swiping
struct ComicPageViewer: View {
    let pages: [ComicPageImage]
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPage: Int = 0

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                if pages.count == 1 {
                    // Single page — zoomable
                    if let uiImage = pages.first?.uiImage {
                        ZoomableImageView(image: uiImage)
                    }
                } else {
                    // Multi-page — swipeable tabs
                    TabView(selection: $selectedPage) {
                        ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                            if let uiImage = page.uiImage {
                                ZoomableImageView(image: uiImage)
                                    .tag(index)
                            }
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .automatic))
                }

                // Page indicator overlay (multi-page only)
                if pages.count > 1 {
                    VStack {
                        Spacer()
                        Text("\(selectedPage + 1) / \(pages.count)")
                            .font(ComicTheme.Typography.sectionHeader(14))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.black.opacity(0.6))
                            .clipShape(Capsule())
                            .padding(.bottom, 60)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }

                ToolbarItem(placement: .confirmationAction) {
                    if let currentPage = pages[safe: selectedPage],
                       let uiImage = currentPage.uiImage {
                        ShareLink(
                            item: Image(uiImage: uiImage),
                            preview: SharePreview("Dream Comic Page", image: Image(uiImage: uiImage))
                        ) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }
}

// MARK: - Safe Array Access

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Zoomable Image View (UIScrollView wrapper)

struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.maximumZoomScale = 4.0
        scrollView.minimumZoomScale = 1.0
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.backgroundColor = .clear

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.tag = 100
        scrollView.addSubview(imageView)

        // Double-tap to zoom
        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        guard let imageView = scrollView.viewWithTag(100) as? UIImageView else { return }
        imageView.image = image

        DispatchQueue.main.async {
            let size = scrollView.bounds.size
            guard size.width > 0, size.height > 0 else { return }

            imageView.frame = CGRect(origin: .zero, size: size)
            scrollView.contentSize = size
            scrollView.zoomScale = 1.0
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            scrollView.viewWithTag(100)
        }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scrollView = gesture.view as? UIScrollView else { return }
            if scrollView.zoomScale > 1.0 {
                scrollView.setZoomScale(1.0, animated: true)
            } else {
                let location = gesture.location(in: scrollView.viewWithTag(100))
                let zoomRect = CGRect(
                    x: location.x - 50,
                    y: location.y - 50,
                    width: 100,
                    height: 100
                )
                scrollView.zoom(to: zoomRect, animated: true)
            }
        }
    }
}
