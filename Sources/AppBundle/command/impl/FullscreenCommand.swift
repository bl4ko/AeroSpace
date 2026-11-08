import AppKit
import Common

struct FullscreenCommand: Command {
    let args: FullscreenCmdArgs
    /*conforms*/ let shouldResetClosedWindowsCache = false

    func run(_ env: CmdEnv, _ io: CmdIo) async -> BinaryExitCode {
        guard let target = args.resolveTargetOrReportError(env, io) else { return .fail }
        guard let window = target.windowOrNil else {
            return .fail(io.err(noWindowIsFocused))
        }
        // 'native-fullscreen-app-ids' (e.g. Screen Sharing locks its aspect ratio, so it can't fill a tiling rect) toggle
        // macOS fullscreen instead. Any other window leaves macOS fullscreen first, then goes AeroSpace fullscreen
        let usesNative = window.usesMacosNativeFullscreen
        if usesNative || window.parent is MacosFullscreenWindowsContainer {
            var nativeArgs = MacosNativeFullscreenCmdArgs(rawArgs: [])
            nativeArgs.windowId = window.windowId
            nativeArgs.toggle = usesNative ? args.toggle : .off
            nativeArgs.failIfNoop = usesNative && args.failIfNoop
            let result = await MacosNativeFullscreenCommand(args: nativeArgs).run(env, io)
            if usesNative {
                window.isFullscreen = false
                return result
            }
        }
        let newState: Bool = switch args.toggle {
            case .on: true
            case .off: false
            case .toggle: !window.isFullscreen
        }
        if newState == window.isFullscreen {
            switch args.failIfNoop {
                case true: return .fail
                case false:
                    let msg = newState
                        ? "Already fullscreen. Tip: use --fail-if-noop to exit with non-zero code"
                        : "Already not fullscreen. Tip: use --fail-if-noop to exit with non-zero code"
                    return .succ(io.err(msg))
            }
        }
        window.isFullscreen = newState
        window.noOuterGapsInFullscreen = args.noOuterGaps

        // Focus on its own workspace
        window.markAsMostRecentChild()
        return .succ
    }
}

let noWindowIsFocused = "No window is focused"

extension Window {
    @MainActor var usesMacosNativeFullscreen: Bool {
        app.rawAppBundleId.map(config.nativeFullscreenAppIds.contains) == true
    }
}
