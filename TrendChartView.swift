import SwiftUI
import Charts

struct TrendChartView: View {
    let dataPoints: [TrendDataPoint]
    let trendDirection: String
    @State private var hiddenEmotions: Set<String> = []

    private var emotions: [String] {
        Array(Set(dataPoints.map { $0.emotion })).sorted()
    }

    private var visibleDataPoints: [TrendDataPoint] {
        dataPoints.filter { !hiddenEmotions.contains($0.emotion) }
    }

    private func colorForEmotion(_ emotion: String) -> Color {
        EmotionBadgeView.emotionColors[emotion.lowercased()] ?? ComicTheme.Colors.boldBlue
    }

    private var trendBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: trendIcon)
                .font(.caption.weight(.bold))
            Text(trendDirection.capitalized)
                .font(.system(size: 11, weight: .bold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(trendColor.opacity(0.15))
        .foregroundColor(trendColor)
        .clipShape(Capsule())
    }

    private var trendIcon: String {
        switch trendDirection.lowercased() {
        case "improving": return "arrow.down.right"
        case "worsening": return "arrow.up.right"
        default: return "minus"
        }
    }

    private var trendColor: Color {
        switch trendDirection.lowercased() {
        case "improving": return ComicTheme.Colors.emeraldGreen
        case "worsening": return ComicTheme.Colors.crimsonRed
        default: return .gray
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Spacer()
                trendBadge
            }

            if dataPoints.count <= 1 {
                VStack(spacing: 8) {
                    Text("Keep logging dreams to see trends")
                        .font(ComicTheme.Typography.speechBubble(13))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                Chart(visibleDataPoints) { point in
                    LineMark(
                        x: .value("Date", point.parsedDate ?? Date()),
                        y: .value("Intensity", point.intensity)
                    )
                    .foregroundStyle(by: .value("Emotion", point.emotion.capitalized))
                    .lineStyle(StrokeStyle(lineWidth: 3))

                    AreaMark(
                        x: .value("Date", point.parsedDate ?? Date()),
                        y: .value("Intensity", point.intensity)
                    )
                    .foregroundStyle(by: .value("Emotion", point.emotion.capitalized))
                    .opacity(0.15)
                }
                .chartForegroundStyleScale { (emotion: String) -> Color in
                    colorForEmotion(emotion.lowercased())
                }
                .chartYScale(domain: 0...1)
                .chartYAxis {
                    AxisMarks(values: [0, 0.25, 0.5, 0.75, 1.0]) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(String(format: "%.0f%%", v * 100))
                                    .font(.system(size: 9, weight: .bold))
                            }
                        }
                    }
                }
                .chartLegend(.hidden)
                .frame(height: 200)
            }

            // Toggleable legend
            FlowLayout(spacing: 6) {
                ForEach(emotions, id: \.self) { emotion in
                    Button {
                        if hiddenEmotions.contains(emotion) {
                            hiddenEmotions.remove(emotion)
                        } else {
                            hiddenEmotions.insert(emotion)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(colorForEmotion(emotion))
                                .frame(width: 8, height: 8)
                            Text(emotion.capitalized)
                                .font(.system(size: 11, weight: .bold))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(hiddenEmotions.contains(emotion) ? Color.gray.opacity(0.1) : colorForEmotion(emotion).opacity(0.15))
                        .foregroundColor(hiddenEmotions.contains(emotion) ? .gray : colorForEmotion(emotion))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(hiddenEmotions.contains(emotion) ? Color.gray.opacity(0.3) : colorForEmotion(emotion).opacity(0.4), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Date Parsing Helper

extension TrendDataPoint {
    var parsedDate: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        if let d = formatter.date(from: date) { return d }
        let fallback = DateFormatter()
        fallback.dateFormat = "yyyy-MM-dd"
        return fallback.date(from: date)
    }
}
