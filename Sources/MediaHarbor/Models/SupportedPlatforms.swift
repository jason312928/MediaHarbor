import Foundation

struct SupportedPlatform: Identifiable, Sendable {
    let id: String
    let name: String
    let symbol: String
    let domains: [String]
    let cookieHelpful: Bool

    static let popular: [SupportedPlatform] = [
        .init(id: "youtube", name: "YouTube", symbol: "play.rectangle.fill", domains: ["youtube.com", "youtu.be"], cookieHelpful: false),
        .init(id: "tiktok", name: "TikTok", symbol: "music.note", domains: ["tiktok.com"], cookieHelpful: true),
        .init(id: "bilibili", name: "哔哩哔哩", symbol: "tv.fill", domains: ["bilibili.com", "b23.tv"], cookieHelpful: true),
        .init(id: "instagram", name: "Instagram", symbol: "camera.fill", domains: ["instagram.com"], cookieHelpful: true),
        .init(id: "x", name: "X / Twitter", symbol: "bubble.left.fill", domains: ["x.com", "twitter.com"], cookieHelpful: true),
        .init(id: "facebook", name: "Facebook", symbol: "person.2.fill", domains: ["facebook.com", "fb.watch"], cookieHelpful: true),
        .init(id: "twitch", name: "Twitch", symbol: "dot.radiowaves.left.and.right", domains: ["twitch.tv"], cookieHelpful: true),
        .init(id: "vimeo", name: "Vimeo", symbol: "play.square.fill", domains: ["vimeo.com"], cookieHelpful: false),
        .init(id: "soundcloud", name: "SoundCloud", symbol: "waveform", domains: ["soundcloud.com"], cookieHelpful: false),
        .init(id: "reddit", name: "Reddit", symbol: "text.bubble.fill", domains: ["reddit.com", "redd.it"], cookieHelpful: false)
    ]

    static func matching(_ urlString: String) -> SupportedPlatform? {
        guard let host = URL(string: urlString)?.host?.lowercased() else { return nil }
        return popular.first { platform in
            platform.domains.contains { host == $0 || host.hasSuffix(".\($0)") }
        }
    }
}
