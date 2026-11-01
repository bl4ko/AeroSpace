@MainActor private var lastKnownNativeFocusedWindowId: UInt32? = nil

/// The data should flow (from nativeFocused to focused) and
///                      (from nativeFocused to lastKnownNativeFocusedWindowId)
/// Alternative names: takeFocusFromMacOs, syncFocusFromMacOs
@MainActor func updateFocusCache(_ nativeFocused: Window?) {
    if nativeFocused?.parent is MacosPopupWindowsContainer {
        return
    }
    if nativeFocused?.windowId != lastKnownNativeFocusedWindowId {
        if let nativeFocused { summonIfNeeded(nativeFocused) }
        _ = nativeFocused?.focusWindow()
        lastKnownNativeFocusedWindowId = nativeFocused?.windowId
    }
    nativeFocused?.macAppUnsafe.lastNativeFocusedWindowId = nativeFocused?.windowId
}

/// 'summon-app-ids': when such an app gets focused (e.g. opened from a launcher), bring its window to the current
/// workspace instead of switching to the window's hidden workspace
@MainActor func summonIfNeeded(_ window: Window) {
    guard let appId = window.app.rawAppBundleId, config.summonAppIds.contains(appId),
          let windowWorkspace = window.nodeWorkspace, !windowWorkspace.isVisible else { return }
    _ = moveWindowToWorkspace(window, focus.workspace, CmdIoImpl.emptyStdinIgnoringOut, focusFollowsWindow: false, failIfNoop: false)
}
