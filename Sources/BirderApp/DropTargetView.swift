import SwiftUI
import AppKit

/// AppKit drag hit-testing walks up the NSView superview chain from whatever
/// `hitTest:` returns until it finds a view registered for a dragged type.
/// SwiftUI's `.onDrop` and `.background(NSViewRepresentable)` both place the
/// drop target as a *sibling* of the SwiftUI hosting view — not in the ancestor
/// chain — so drags into nested content (HSplitView + ScrollView + pinned
/// Section headers) never reach them on macOS.
///
/// The fix: replace `window.contentView` with a drop-registered NSView and
/// reparent the original hosting view as its child. Every SwiftUI view is then
/// a descendant, so drag events from any inner region bubble up.
@MainActor
final class WindowDropHandler {
    static let shared = WindowDropHandler()

    private weak var installedView: DropAncestorView?

    /// Per-screen-state callbacks. Reassigned every SessionDetailView render.
    var onDrop: (([URL]) -> Bool)?
    var onTargeted: ((Bool) -> Void)?

    func install(in window: NSWindow) {
        if window.contentView is DropAncestorView { return }
        guard let old = window.contentView else { return }
        let wrapper = DropAncestorView(frame: old.bounds)
        wrapper.handler = self
        wrapper.autoresizingMask = [.width, .height]
        window.contentView = wrapper
        old.frame = wrapper.bounds
        old.autoresizingMask = [.width, .height]
        wrapper.addSubview(old)
        self.installedView = wrapper
    }
}

final class DropAncestorView: NSView {
    weak var handler: WindowDropHandler?

    override init(frame: NSRect) {
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL])
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        handler?.onTargeted?(true)
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        handler?.onTargeted?(false)
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        handler?.onTargeted?(false)
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        true
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        handler?.onTargeted?(false)
        guard let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self]) as? [URL] else {
            return false
        }
        return handler?.onDrop?(urls) ?? false
    }
}

/// Exposes the window hosting this view so callers can install handlers once
/// the view is attached. Fires on attachment and on every update (idempotent
/// callers required).
struct WindowAccessor: NSViewRepresentable {
    let callback: (NSWindow) -> Void

    func makeNSView(context: Context) -> WindowAccessorNSView {
        let view = WindowAccessorNSView()
        view.callback = callback
        return view
    }

    func updateNSView(_ view: WindowAccessorNSView, context: Context) {
        view.callback = callback
        if let window = view.window {
            let cb = callback
            DispatchQueue.main.async { cb(window) }
        }
    }
}

final class WindowAccessorNSView: NSView {
    var callback: ((NSWindow) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let window = self.window {
            let cb = self.callback
            DispatchQueue.main.async {
                cb?(window)
            }
        }
    }
}
