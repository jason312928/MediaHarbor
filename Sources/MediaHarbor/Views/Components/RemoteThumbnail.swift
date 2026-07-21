import AppKit
import OSLog
import SwiftUI

struct RemoteThumbnail: View {
    let urlString: String?
    let refererURLString: String?
    var contentMode: ContentMode = .fit
    var placeholderSymbol = "play.rectangle.fill"
    var onAspectRatioChange: ((CGFloat) -> Void)? = nil

    @State private var image: NSImage?
    @State private var failed = false

    var body: some View {
        ZStack {
            Rectangle().fill(.quaternary)
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if failed {
                Image(systemName: "photo.badge.exclamationmark")
                    .font(.title2)
                    .foregroundStyle(.tertiary)
            } else {
                Image(systemName: placeholderSymbol)
                    .font(.title2)
                    .foregroundStyle(.tertiary)
            }
        }
        .task(id: urlString) { await load() }
    }

    private func load() async {
        image = nil
        failed = false
        guard let request = ThumbnailRequestFactory.request(urlString: urlString, refererURLString: refererURLString) else {
            failed = urlString != nil
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
                throw ThumbnailLoadError.badStatus((response as? HTTPURLResponse)?.statusCode)
            }
            guard let loadedImage = NSImage(data: data) else { throw ThumbnailLoadError.invalidImage }
            guard !Task.isCancelled else { return }
            image = loadedImage
            if loadedImage.size.width > 0, loadedImage.size.height > 0 {
                onAspectRatioChange?(loadedImage.size.width / loadedImage.size.height)
            }
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            failed = true
            ThumbnailRequestFactory.logger.error("Thumbnail load failed for \(request.url?.absoluteString ?? "unknown", privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }
}

enum ThumbnailRequestFactory {
    static let logger = Logger(subsystem: "app.mediaharbor.desktop", category: "thumbnail")

    static func request(urlString: String?, refererURLString: String?) -> URLRequest? {
        guard let url = normalizedURL(from: urlString) else { return nil }
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        request.timeoutInterval = 20
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 Safari/605.1.15", forHTTPHeaderField: "User-Agent")
        if let referer = referer(for: url, sourceURLString: refererURLString) {
            request.setValue(referer, forHTTPHeaderField: "Referer")
        }
        return request
    }

    static func normalizedURL(from string: String?) -> URL? {
        guard var value = string?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        if value.hasPrefix("//") { value = "https:\(value)" }
        guard var components = URLComponents(string: value) else { return nil }
        if components.scheme?.lowercased() == "http" { components.scheme = "https" }
        return components.url
    }

    private static func referer(for imageURL: URL, sourceURLString: String?) -> String? {
        let host = imageURL.host?.lowercased() ?? ""
        if host == "hdslb.com" || host.hasSuffix(".hdslb.com") {
            return "https://www.bilibili.com/"
        }
        guard let sourceURLString, let source = URL(string: sourceURLString),
              let scheme = source.scheme, let host = source.host else { return nil }
        return "\(scheme)://\(host)/"
    }
}

private enum ThumbnailLoadError: LocalizedError {
    case badStatus(Int?)
    case invalidImage

    var errorDescription: String? {
        switch self {
        case .badStatus(let status): "HTTP \(status.map(String.init) ?? "response error")"
        case .invalidImage: "Response was not a supported image"
        }
    }
}
