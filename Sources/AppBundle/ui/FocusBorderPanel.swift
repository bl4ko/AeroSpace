import AppKit

// macOS doesn't expose window corner radii. Matches regular windows closely enough
private let windowCornerRadius: CGFloat = 12

@MainActor private var focusBorder: FocusBorderPanel? = nil

/// Hyprland/Omarchy-like border around the focused window. Disabled when 'focused-border-width' is 0
@MainActor
func refreshFocusBorder() async throws {
    let width = CGFloat(config.focusedBorderWidth)
    guard width > 0, TrayMenuModel.shared.isEnabled,
          let window = focus.windowOrNil, window.nodeWorkspace?.isVisible == true,
          // Tiling windows: the rect we just applied (the AX rect may lag behind). Fullscreen windows have none
          let rect = window.isFloating ? try await window.getAxRect(.cancellable) : window.lastAppliedLayoutPhysicalRect
    else {
        focusBorder?.orderOut(nil)
        return
    }
    let panel = focusBorder ?? FocusBorderPanel()
    focusBorder = panel
    panel.show(around: rect, width: width, color: config.focusedBorderColor)
}

// ponytail: .floating level draws over unfocused floating windows that overlap the focused one.
// Ordering right above the focused window needs private SkyLight APIs
private final class FocusBorderPanel: NSPanelHud {
    override init() {
        super.init()
        ignoresMouseEvents = true
        hasShadow = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        contentView?.wantsLayer = true
    }

    func show(around rect: Rect, width: CGFloat, color: UInt32) {
        guard let layer = contentView?.layer else { return }
        layer.borderWidth = width
        layer.cornerRadius = windowCornerRadius + width
        layer.borderColor = CGColor(
            red: CGFloat((color >> 16) & 0xFF) / 255,
            green: CGFloat((color >> 8) & 0xFF) / 255,
            blue: CGFloat(color & 0xFF) / 255,
            alpha: CGFloat(color >> 24) / 255,
        )
        // AeroSpace rects are top-left based, AppKit frames are bottom-left based
        setFrame(NSRect(
            x: rect.minX - width,
            y: mainMonitor.height - rect.maxY - width,
            width: rect.width + 2 * width,
            height: rect.height + 2 * width,
        ), display: true)
        orderFrontRegardless()
    }
}
