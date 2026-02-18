import Foundation

// MARK: - Dream Analysis Response (POST + GET by dreamId)

struct DreamAnalysisResponse: Codable {
    let dream_id: String?
    let emotions: [EmotionResult]
    let suggested_mood: SuggestedMood
    let analyzed_at: String?
}

struct EmotionResult: Codable, Identifiable {
    var id: String { emotion + String(intensity) }
    let emotion: String
    let intensity: Double
    let label: String?
}

struct SuggestedMood: Codable {
    let mood: String
    let suggestion_reason: String
}

// MARK: - Trends Response

struct TrendsResponse: Codable {
    let period: String?
    let data_points: [TrendDataPoint]
    let trend_direction: String

    enum CodingKeys: String, CodingKey {
        case period
        case data_points
        case dataPoints = "dataPoints"
        case trend_direction
        case trendDirection = "trendDirection"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        period = try container.decodeIfPresent(String.self, forKey: .period)
        // Accept both snake_case and camelCase
        if let dp = try? container.decode([TrendDataPoint].self, forKey: .data_points) {
            data_points = dp
        } else {
            data_points = (try? container.decode([TrendDataPoint].self, forKey: .dataPoints)) ?? []
        }
        if let td = try? container.decode(String.self, forKey: .trend_direction) {
            trend_direction = td
        } else {
            trend_direction = (try? container.decode(String.self, forKey: .trendDirection)) ?? "stable"
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(period, forKey: .period)
        try container.encode(data_points, forKey: .data_points)
        try container.encode(trend_direction, forKey: .trend_direction)
    }
}

struct TrendDataPoint: Codable, Identifiable {
    var id: String { date + emotion }
    let date: String
    let emotion: String
    let intensity: Double
}

// MARK: - Summary Response

struct AnalysisSummaryResponse: Codable {
    let period: String?
    let dreams_analyzed: Int
    let most_common_emotion: String
    let most_common_intensity: Double
    let mood_distribution: [MoodDistributionEntry]
    let sparkline_data: [Double]?

    enum CodingKeys: String, CodingKey {
        case period
        case dreams_analyzed
        case dreamsAnalyzed = "dreamsAnalyzed"
        case most_common_emotion
        case mostCommonEmotion = "mostCommonEmotion"
        case most_common_intensity
        case mostCommonIntensity = "mostCommonIntensity"
        case mood_distribution
        case moodDistribution = "moodDistribution"
        case sparkline_data
        case sparklineData = "sparklineData"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        period = try container.decodeIfPresent(String.self, forKey: .period)

        // dreams_analyzed: accept Int or String
        if let val = try? container.decode(Int.self, forKey: .dreams_analyzed) {
            dreams_analyzed = val
        } else if let val = try? container.decode(Int.self, forKey: .dreamsAnalyzed) {
            dreams_analyzed = val
        } else {
            dreams_analyzed = 0
        }

        // most_common_emotion
        if let val = try? container.decode(String.self, forKey: .most_common_emotion) {
            most_common_emotion = val
        } else if let val = try? container.decode(String.self, forKey: .mostCommonEmotion) {
            most_common_emotion = val
        } else {
            most_common_emotion = "unknown"
        }

        // most_common_intensity
        if let val = try? container.decode(Double.self, forKey: .most_common_intensity) {
            most_common_intensity = val
        } else if let val = try? container.decode(Double.self, forKey: .mostCommonIntensity) {
            most_common_intensity = val
        } else {
            most_common_intensity = 0.0
        }

        // mood_distribution
        if let val = try? container.decode([MoodDistributionEntry].self, forKey: .mood_distribution) {
            mood_distribution = val
        } else if let val = try? container.decode([MoodDistributionEntry].self, forKey: .moodDistribution) {
            mood_distribution = val
        } else {
            mood_distribution = []
        }

        // sparkline_data
        if let val = try? container.decode([Double].self, forKey: .sparkline_data) {
            sparkline_data = val
        } else if let val = try? container.decode([Double].self, forKey: .sparklineData) {
            sparkline_data = val
        } else {
            sparkline_data = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(period, forKey: .period)
        try container.encode(dreams_analyzed, forKey: .dreams_analyzed)
        try container.encode(most_common_emotion, forKey: .most_common_emotion)
        try container.encode(most_common_intensity, forKey: .most_common_intensity)
        try container.encode(mood_distribution, forKey: .mood_distribution)
        try container.encodeIfPresent(sparkline_data, forKey: .sparkline_data)
    }
}

struct MoodDistributionEntry: Codable, Identifiable {
    var id: String { mood }
    let mood: String
    let count: Int
    let percentage: Double
}
