import UIKit

/// Composites individual panel images into a single comic book page
/// using layout metadata from the backend or local AI planning step.
enum ComicPageCompositor {

    static let defaultPageSize = CGSize(width: 1024, height: 1536)

    // MARK: - Public API

    /// Compose a single comic page from panel images + layout plan
    static func composePage(
        panelImages: [UIImage],
        pagePlan: ComicPagePlan,
        layoutType: String,
        titleText: String? = nil,
        pageSize: CGSize = defaultPageSize
    ) -> UIImage? {
        guard !panelImages.isEmpty else { return nil }

        let renderer = UIGraphicsImageRenderer(size: pageSize)

        return renderer.image { context in
            let ctx = context.cgContext
            let margin: CGFloat = 20
            let gutter: CGFloat = 12
            let borderWidth: CGFloat = 4
            let titleHeight: CGFloat = titleText != nil ? 60 : 0

            // 1. Draw white background
            ctx.setFillColor(UIColor.white.cgColor)
            ctx.fill(CGRect(origin: .zero, size: pageSize))

            // 2. Draw subtle halftone texture
            drawHalftonePattern(ctx: ctx, size: pageSize)

            // 3. Draw title banner if present
            if let title = titleText {
                drawTitleBanner(ctx: ctx, title: title, pageWidth: pageSize.width, height: titleHeight)
            }

            // 4. Calculate panel frames based on layout type
            let contentRect = CGRect(
                x: margin,
                y: margin + titleHeight,
                width: pageSize.width - margin * 2,
                height: pageSize.height - margin * 2 - titleHeight
            )
            let frames = calculatePanelFrames(
                layout: layoutType,
                count: panelImages.count,
                contentRect: contentRect,
                gutter: gutter
            )

            // 5. Draw each panel
            for (index, image) in panelImages.enumerated() {
                guard index < frames.count else { break }
                let frame = frames[index]

                // Panel shadow
                ctx.setShadow(offset: CGSize(width: 3, height: 3), blur: 5,
                              color: UIColor.black.withAlphaComponent(0.3).cgColor)
                ctx.setFillColor(UIColor.white.cgColor)
                ctx.fill(frame)
                ctx.setShadow(offset: .zero, blur: 0)

                // Panel image (aspect fill)
                let imageFrame = frame.insetBy(dx: borderWidth, dy: borderWidth)
                drawImageAspectFill(image: image, in: imageFrame, context: ctx)

                // Panel border
                ctx.setStrokeColor(UIColor.black.cgColor)
                ctx.setLineWidth(borderWidth)
                ctx.stroke(frame.insetBy(dx: borderWidth / 2, dy: borderWidth / 2))

                // Speech bubble overlay
                if index < pagePlan.panels.count,
                   let speechText = pagePlan.panels[index].speech_bubble,
                   !speechText.isEmpty {
                    drawSpeechBubble(ctx: ctx, text: speechText, panelFrame: frame)
                }

                // Sound effect overlay
                if index < pagePlan.panels.count,
                   let effectText = pagePlan.panels[index].sound_effect,
                   !effectText.isEmpty {
                    drawSoundEffect(ctx: ctx, text: effectText, panelFrame: frame)
                }
            }

            // 6. Page border
            ctx.setStrokeColor(UIColor.black.cgColor)
            ctx.setLineWidth(2)
            ctx.stroke(CGRect(origin: .zero, size: pageSize).insetBy(dx: 4, dy: 4))
        }
    }

    // MARK: - Layout Calculation

    private static func calculatePanelFrames(
        layout: String,
        count: Int,
        contentRect: CGRect,
        gutter: CGFloat
    ) -> [CGRect] {
        let x = contentRect.minX
        let y = contentRect.minY
        let w = contentRect.width
        let h = contentRect.height

        switch layout {
        case "single_splash":
            return [CGRect(x: x, y: y, width: w, height: h)]

        case "vertical_strip":
            let ph = (h - gutter * CGFloat(count - 1)) / CGFloat(count)
            return (0..<count).map {
                CGRect(x: x, y: y + (ph + gutter) * CGFloat($0), width: w, height: ph)
            }

        case "2x2_grid":
            let cols = 2
            let rows = Int(ceil(Double(count) / Double(cols)))
            let pw = (w - gutter * CGFloat(cols - 1)) / CGFloat(cols)
            let ph = (h - gutter * CGFloat(rows - 1)) / CGFloat(rows)
            return (0..<count).map {
                CGRect(
                    x: x + (pw + gutter) * CGFloat($0 % cols),
                    y: y + (ph + gutter) * CGFloat($0 / cols),
                    width: pw,
                    height: ph
                )
            }

        case "dynamic":
            return createDynamicLayout(count: count, x: x, y: y, w: w, h: h, gutter: gutter)

        default:
            // Fallback to grid
            let cols = count <= 2 ? 1 : 2
            let rows = Int(ceil(Double(count) / Double(cols)))
            let pw = (w - gutter * CGFloat(cols - 1)) / CGFloat(cols)
            let ph = (h - gutter * CGFloat(rows - 1)) / CGFloat(rows)
            return (0..<count).map {
                CGRect(
                    x: x + (pw + gutter) * CGFloat($0 % cols),
                    y: y + (ph + gutter) * CGFloat($0 / cols),
                    width: pw,
                    height: ph
                )
            }
        }
    }

    private static func createDynamicLayout(
        count: Int, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, gutter: CGFloat
    ) -> [CGRect] {
        switch count {
        case 1:
            return [CGRect(x: x, y: y, width: w, height: h)]
        case 2:
            return [
                CGRect(x: x, y: y, width: w, height: h * 0.58),
                CGRect(x: x, y: y + h * 0.58 + gutter, width: w, height: h * 0.42 - gutter)
            ]
        case 3:
            let topH = h * 0.55
            let botH = h - topH - gutter
            let halfW = (w - gutter) / 2
            return [
                CGRect(x: x, y: y, width: w, height: topH),
                CGRect(x: x, y: y + topH + gutter, width: halfW, height: botH),
                CGRect(x: x + halfW + gutter, y: y + topH + gutter, width: halfW, height: botH)
            ]
        case 4:
            let halfW = (w - gutter) / 2
            let topH = h * 0.48
            let botH = h - topH - gutter
            return [
                CGRect(x: x, y: y, width: halfW * 0.85, height: topH),
                CGRect(x: x + halfW * 0.85 + gutter, y: y, width: halfW * 1.15, height: topH),
                CGRect(x: x, y: y + topH + gutter, width: halfW * 1.15, height: botH),
                CGRect(x: x + halfW * 1.15 + gutter, y: y + topH + gutter, width: halfW * 0.85, height: botH)
            ]
        case 5:
            let topH = h * 0.35
            let midH = h * 0.30
            let botH = h - topH - midH - gutter * 2
            let halfW = (w - gutter) / 2
            let thirdW = (w - gutter * 2) / 3
            return [
                CGRect(x: x, y: y, width: halfW, height: topH),
                CGRect(x: x + halfW + gutter, y: y, width: halfW, height: topH),
                CGRect(x: x, y: y + topH + gutter, width: w, height: midH),
                CGRect(x: x, y: y + topH + midH + gutter * 2, width: thirdW * 1.5, height: botH),
                CGRect(x: x + thirdW * 1.5 + gutter, y: y + topH + midH + gutter * 2, width: thirdW * 1.5, height: botH)
            ]
        default:
            let ph = (h - gutter * CGFloat(count - 1)) / CGFloat(count)
            return (0..<count).map {
                CGRect(x: x, y: y + (ph + gutter) * CGFloat($0), width: w, height: ph)
            }
        }
    }

    // MARK: - Drawing Helpers

    private static func drawImageAspectFill(image: UIImage, in rect: CGRect, context: CGContext) {
        let imageAspect = image.size.width / image.size.height
        let rectAspect = rect.width / rect.height

        var drawRect: CGRect
        if imageAspect > rectAspect {
            let scaledWidth = rect.height * imageAspect
            drawRect = CGRect(x: rect.minX - (scaledWidth - rect.width) / 2,
                              y: rect.minY, width: scaledWidth, height: rect.height)
        } else {
            let scaledHeight = rect.width / imageAspect
            drawRect = CGRect(x: rect.minX, y: rect.minY - (scaledHeight - rect.height) / 2,
                              width: rect.width, height: scaledHeight)
        }

        context.saveGState()
        context.clip(to: rect)
        image.draw(in: drawRect)
        context.restoreGState()
    }

    private static func drawHalftonePattern(ctx: CGContext, size: CGSize) {
        ctx.setFillColor(UIColor.black.withAlphaComponent(0.04).cgColor)
        let spacing: CGFloat = 14
        for x in stride(from: CGFloat(0), to: size.width, by: spacing) {
            for y in stride(from: CGFloat(0), to: size.height, by: spacing) {
                let offset: CGFloat = Int(y / spacing) % 2 == 0 ? spacing / 2 : 0
                ctx.fillEllipse(in: CGRect(x: x + offset, y: y, width: 2.5, height: 2.5))
            }
        }
    }

    private static func drawTitleBanner(ctx: CGContext, title: String, pageWidth: CGFloat, height: CGFloat) {
        // Blue banner background
        ctx.setFillColor(UIColor(red: 0x1A / 255, green: 0x56 / 255, blue: 0xDB / 255, alpha: 1).cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: pageWidth, height: height))

        // Title text
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 32, weight: .black),
            .foregroundColor: UIColor.white,
            .kern: 3.0
        ]
        let textSize = title.size(withAttributes: attrs)
        let textX = (pageWidth - textSize.width) / 2
        let textY = (height - textSize.height) / 2
        title.draw(at: CGPoint(x: textX, y: textY), withAttributes: attrs)
    }

    private static func drawSpeechBubble(ctx: CGContext, text: String, panelFrame: CGRect) {
        let maxWidth: CGFloat = panelFrame.width * 0.7
        let padding: CGFloat = 10
        let tailHeight: CGFloat = 14

        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16, weight: .medium),
            .foregroundColor: UIColor.black
        ]

        let textRect = (text as NSString).boundingRect(
            with: CGSize(width: maxWidth - padding * 2, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attrs,
            context: nil
        )

        let bubbleWidth = textRect.width + padding * 2
        let bubbleHeight = textRect.height + padding * 2
        let bubbleX = panelFrame.midX - bubbleWidth / 2
        let bubbleY = panelFrame.maxY - bubbleHeight - tailHeight - 20

        // Bubble shape
        let bubbleRect = CGRect(x: bubbleX, y: bubbleY, width: bubbleWidth, height: bubbleHeight)
        let bubblePath = UIBezierPath(roundedRect: bubbleRect, cornerRadius: 10)

        // Tail
        let tailX = bubbleRect.midX
        bubblePath.move(to: CGPoint(x: tailX - 8, y: bubbleRect.maxY))
        bubblePath.addLine(to: CGPoint(x: tailX, y: bubbleRect.maxY + tailHeight))
        bubblePath.addLine(to: CGPoint(x: tailX + 8, y: bubbleRect.maxY))

        ctx.saveGState()
        ctx.setFillColor(UIColor.white.cgColor)
        ctx.setStrokeColor(UIColor.black.cgColor)
        ctx.setLineWidth(2)
        bubblePath.fill()
        bubblePath.stroke()
        ctx.restoreGState()

        // Text
        text.draw(
            in: CGRect(x: bubbleX + padding, y: bubbleY + padding,
                       width: bubbleWidth - padding * 2, height: bubbleHeight - padding * 2),
            withAttributes: attrs
        )
    }

    private static func drawSoundEffect(ctx: CGContext, text: String, panelFrame: CGRect) {
        let centerX = panelFrame.minX + panelFrame.width * 0.75
        let centerY = panelFrame.minY + panelFrame.height * 0.2

        // Explosion burst shape
        ctx.saveGState()
        let burstPath = UIBezierPath()
        let points = 14
        let outerR: CGFloat = 60
        let innerR: CGFloat = 38
        for i in 0..<points * 2 {
            let angle = CGFloat(i) * .pi / CGFloat(points) - .pi / 2
            let r = i % 2 == 0 ? outerR : innerR
            let px = centerX + cos(angle) * r
            let py = centerY + sin(angle) * r
            if i == 0 {
                burstPath.move(to: CGPoint(x: px, y: py))
            } else {
                burstPath.addLine(to: CGPoint(x: px, y: py))
            }
        }
        burstPath.close()

        ctx.setFillColor(UIColor(red: 0xF5 / 255, green: 0x9E / 255, blue: 0x0B / 255, alpha: 1).cgColor)
        ctx.setStrokeColor(UIColor.black.cgColor)
        ctx.setLineWidth(3)
        burstPath.fill()
        burstPath.stroke()
        ctx.restoreGState()

        // Sound effect text
        let textAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 28, weight: .black),
            .foregroundColor: UIColor.red,
            .strokeColor: UIColor.black,
            .strokeWidth: -3
        ]
        let textSize = text.size(withAttributes: textAttrs)
        text.draw(
            at: CGPoint(x: centerX - textSize.width / 2, y: centerY - textSize.height / 2),
            withAttributes: textAttrs
        )
    }
}
