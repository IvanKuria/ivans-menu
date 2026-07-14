import Foundation

public enum ClockFormatter {
    public static func time(hour: Int, minute: Int, blinkOn: Bool,
                            twentyFourHour: Bool) -> String {
        var h = hour
        if !twentyFourHour { h = hour % 12; if h == 0 { h = 12 } }
        let sep = blinkOn ? ":" : " "
        return String(format: "%02d%@%02d", h, sep, minute)
    }

    public static func date(_ date: Date, calendar: Calendar) -> String {
        let df = DateFormatter()
        df.calendar = calendar; df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = calendar.timeZone
        df.dateFormat = "EEE"
        let weekday = df.string(from: date)
        let c = calendar.dateComponents([.day, .month], from: date)
        return "\(weekday) \(c.month!)/\(c.day!)"
    }
}
