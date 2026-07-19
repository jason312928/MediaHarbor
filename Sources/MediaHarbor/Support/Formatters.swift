import Foundation

enum MediaFormatters {
    static let relativeDate: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()

    static func duration(_ seconds: Double?, language: AppLanguage = .english) -> String {
        guard let seconds else { return L10n.text("unknown_duration", language) }
        return Duration.seconds(seconds).formatted(.time(pattern: .hourMinuteSecond(padHourToLength: 1)))
    }

    static func count(_ value: Int?) -> String? {
        guard let value else { return nil }
        return value.formatted(.number.notation(.compactName))
    }
}
