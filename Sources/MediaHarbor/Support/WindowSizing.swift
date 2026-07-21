import AppKit
import SwiftUI

@MainActor
final class WeakWindowReference {
    weak var window: NSWindow?
}

struct WindowAccessor: NSViewRepresentable {
    let reference: WeakWindowReference

    func makeNSView(context: Context) -> NSView {
        WindowCaptureView(reference: reference)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        reference.window = nsView.window
    }
}

private final class WindowCaptureView: NSView {
    weak var reference: WeakWindowReference?

    init(reference: WeakWindowReference) {
        self.reference = reference
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        reference?.window = window
    }
}

enum WindowSizing {
    enum ExpansionAnchor {
        case leadingEdge
        case trailingEdge
    }

    static let detailWidth: CGFloat = 680
    static let sidebarWidth: CGFloat = 210
    static let inspectorWidth: CGFloat = 270
    static let expansionDuration = 0.24

    static func requiredContentWidth(sidebar: Bool, inspector: Bool) -> CGFloat {
        detailWidth + (sidebar ? sidebarWidth : 0) + (inspector ? inspectorWidth : 0)
    }

    @MainActor
    static func needsExpansion(_ window: NSWindow?, sidebar: Bool, inspector: Bool) -> Bool {
        guard let window else { return false }
        return window.contentLayoutRect.width + 1 < requiredContentWidth(sidebar: sidebar, inspector: inspector)
    }

    @MainActor
    static func expandIfNeeded(
        _ window: NSWindow?,
        sidebar: Bool,
        inspector: Bool,
        anchor: ExpansionAnchor,
        completion: @escaping () -> Void
    ) {
        guard let window else { completion(); return }
        let fixedEdge = anchor == .leadingEdge ? window.frame.minX : window.frame.maxX
        let requiredWidth = requiredContentWidth(sidebar: sidebar, inspector: inspector)
        let currentContentWidth = window.contentLayoutRect.width
        guard currentContentWidth + 1 < requiredWidth else {
            completion()
            constrainAfterLayout(
                window,
                anchor: anchor,
                fixedEdge: fixedEdge,
                targetFrameWidth: window.frame.width
            )
            return
        }

        var frame = window.frame
        let requestedFrameWidth = frame.width + requiredWidth - currentContentWidth
        let visibleFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame
        frame.size.width = min(requestedFrameWidth, visibleFrame?.width ?? requestedFrameWidth)

        if let visibleFrame {
            frame.origin.x = anchoredOriginX(
                oldFrame: window.frame,
                newWidth: frame.width,
                anchor: anchor,
                visibleFrame: visibleFrame
            )
        }
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            window.setFrame(frame, display: true, animate: false)
            completion()
            constrainAfterLayout(
                window,
                anchor: anchor,
                fixedEdge: fixedEdge,
                targetFrameWidth: frame.width
            )
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = expansionDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(frame, display: true)
        } completionHandler: {
            DispatchQueue.main.async {
                completion()
                constrainAfterLayout(
                    window,
                    anchor: anchor,
                    fixedEdge: fixedEdge,
                    targetFrameWidth: frame.width
                )
            }
        }
    }

    static func anchoredOriginX(
        oldFrame: CGRect,
        newWidth: CGFloat,
        anchor: ExpansionAnchor,
        visibleFrame: CGRect
    ) -> CGFloat {
        let desiredOrigin: CGFloat
        switch anchor {
        case .leadingEdge:
            desiredOrigin = oldFrame.minX
        case .trailingEdge:
            desiredOrigin = oldFrame.maxX - newWidth
        }
        return min(max(desiredOrigin, visibleFrame.minX), visibleFrame.maxX - newWidth)
    }

    @MainActor
    static func constrainToVisibleScreen(
        _ window: NSWindow?,
        anchor: ExpansionAnchor,
        fixedEdge: CGFloat,
        targetFrameWidth: CGFloat
    ) {
        guard let window, let visibleFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame else { return }
        var frame = window.frame
        frame.size.width = min(targetFrameWidth, visibleFrame.width)
        frame.size.height = min(frame.height, visibleFrame.height)
        let desiredOrigin = anchor == .leadingEdge ? fixedEdge : fixedEdge - frame.width
        frame.origin.x = min(max(desiredOrigin, visibleFrame.minX), visibleFrame.maxX - frame.width)
        frame.origin.y = min(max(frame.origin.y, visibleFrame.minY), visibleFrame.maxY - frame.height)
        if frame != window.frame {
            window.setFrame(frame, display: true, animate: false)
        }
    }

    @MainActor
    static func constrainAfterLayout(
        _ window: NSWindow?,
        anchor: ExpansionAnchor,
        fixedEdge: CGFloat,
        targetFrameWidth: CGFloat
    ) {
        guard let window else { return }
        constrainToVisibleScreen(window, anchor: anchor, fixedEdge: fixedEdge, targetFrameWidth: targetFrameWidth)
        DispatchQueue.main.async { [weak window] in
            constrainToVisibleScreen(window, anchor: anchor, fixedEdge: fixedEdge, targetFrameWidth: targetFrameWidth)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak window] in
            constrainToVisibleScreen(window, anchor: anchor, fixedEdge: fixedEdge, targetFrameWidth: targetFrameWidth)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak window] in
            constrainToVisibleScreen(window, anchor: anchor, fixedEdge: fixedEdge, targetFrameWidth: targetFrameWidth)
        }
    }
}
