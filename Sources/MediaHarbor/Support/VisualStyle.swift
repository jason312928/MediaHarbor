import SwiftUI

extension View {
    func harborCard(cornerRadius: CGFloat = 20) -> some View {
        modifier(HarborCardModifier(cornerRadius: cornerRadius))
    }
}

private struct HarborCardModifier: ViewModifier {
    let cornerRadius: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            content
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(.separator.opacity(0.35))
                }
        }
    }
}

struct StatusDot: View {
    let status: DownloadStatus

    var color: Color {
        switch status {
        case .completed: .green
        case .failed: .red
        case .cancelled: .secondary
        case .queued: .orange
        default: .blue
        }
    }

    var body: some View {
        Circle().fill(color).frame(width: 7, height: 7).accessibilityHidden(true)
    }
}
