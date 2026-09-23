import AppKit
import Combine
import SwiftUI

/// Floats over every app and Space and never takes focus: typed text must land in the app you are using.
final class BarPanel: NSPanel {
    /// Room around the bar for its SwiftUI shadow.
    static let margin: CGFloat = 16
    private static let autosave = "halfsay.bar"

    private var changes: AnyCancellable?

    init(model: BarModel) {
        let host = FirstClickHostingView(rootView: BarView(model: model).padding(Self.margin).fixedSize())
        super.init(contentRect: NSRect(origin: .zero, size: host.fittingSize), styleMask: [.nonactivatingPanel, .borderless],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        contentView = host
        if !setFrameUsingName(Self.autosave) { placeTopCenter() }
        setFrameAutosaveName(Self.autosave)
        // Fit the window to the bar after every change, growing downward so nothing invisible sits over other apps.
        changes = model.objectWillChange.sink { [weak self] _ in
            Task { @MainActor in self?.fitContent() }
        }
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    private var dragStart: (mouse: NSPoint, origin: NSPoint)?

    /// Moves the bar with the mouse. Done by hand because a window-background drag would swallow the play/pause click.
    func drag(_ phase: BarModel.Drag) {
        let mouse = NSEvent.mouseLocation
        switch phase {
        case .moved:
            let start = dragStart ?? (mouse, frame.origin)
            dragStart = start
            setFrameOrigin(NSPoint(x: start.origin.x + mouse.x - start.mouse.x, y: start.origin.y + mouse.y - start.mouse.y))
        case .ended:
            dragStart = nil
        }
    }

    private func fitContent() {
        guard let height = contentView?.fittingSize.height, abs(height - frame.height) > 0.5 else { return }
        setFrame(NSRect(x: frame.minX, y: frame.maxY - height, width: frame.width, height: height), display: true)
    }

    private func placeTopCenter() {
        guard let screen = NSScreen.main?.visibleFrame else { return }
        setFrameOrigin(NSPoint(x: screen.midX - frame.width / 2, y: screen.maxY - frame.height))
    }
}

/// The panel never becomes key, so every click is a first click: take it, or the play/pause button never fires.
private final class FirstClickHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
