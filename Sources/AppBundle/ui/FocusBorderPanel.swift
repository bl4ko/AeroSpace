import AppKit

// macOS doesn't expose window corner radii. Matches regular windows closely enough
private let windowCornerRadius: CGFloat = 12

@MainActor private var focusBorder: FocusBorderPanel? = nil

/// Hyprland/Omarchy-like border around the focused window. Disabled when 'focused-border-width' is 0
@MainActor
func refreshFocusBorder() async throws {
    let width = CGFloat(config.focusedBorderWidth)
    guard width > 0, TrayMenuModel.shared.isEnabled,
          let window = focus.windowOrNil, window.nodeWorkspace?.isVisible == true
    else {
        focusBorder?.orderOut(nil)
        return
    }
    // Tiling windows: the rect we just applied (the AX rect may lag behind). Fullscreen windows have none
    guard let rect = window.isFloating ? try await window.getAxRect(.cancellable) : window.lastAppliedLayoutPhysicalRect else {
        // A busy app can fail the AX read (e.g. while a terminal redraws). Keep the floating window's border instead of blinking
        if !window.isFloating { focusBorder?.orderOut(nil) }
        return
    }
    let panel = focusBorder ?? FocusBorderPanel()
    focusBorder = panel
    panel.show(around: rect, above: window.windowId, width: width, color: config.focusedBorderColor)
}

private final class FocusBorderPanel: NSPanelHud {
    override init() {
        super.init()
        // Normal level + ordering right above the focused window. Its sheets/dialogs and windows in front stay on top
        level = .normal
        // macOS plays a grow-in animation every time a window is shown, which made the border lag behind
        animationBehavior = .none
        ignoresMouseEvents = true
        hasShadow = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        contentView?.wantsLayer = true
    }

    func show(around rect: Rect, above windowId: UInt32, width: CGFloat, color: UInt32) {
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
        order(.above, relativeTo: Int(windowId))
    }
}
