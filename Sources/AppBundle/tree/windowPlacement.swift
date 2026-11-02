import AppKit
import Common

/// AeroSpace forgets window placement when it quits, so on startup on-window-detected rules reshuffle windows that the
/// user placed by hand. Remember each window's workspace across restarts. Window ids are unique while the app runs, and
/// the pid guards against ids reused after the app restarts
private struct Placement: Codable, Equatable {
    let pid: Int32
    let workspace: String
    let isFloating: Bool
}

private let placementFile = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".cache/aerospace/window-placement.json")
@MainActor private var savedPlacements: [String: Placement] =
    (try? JSONDecoder().decode([String: Placement].self, from: Data(contentsOf: placementFile))) ?? [:]
@MainActor private var lastWrittenPlacements: [String: Placement]? = nil

@MainActor func saveWindowPlacement() {
    var placements: [String: Placement] = [:]
    for workspace in Workspace.all {
        for case let window as MacWindow in workspace.allLeafWindowsRecursive {
            placements[String(window.windowId)] = Placement(pid: window.macApp.pid, workspace: workspace.name, isFloating: window.isFloating)
        }
    }
    if placements == lastWrittenPlacements { return }
    lastWrittenPlacements = placements
    try? FileManager.default.createDirectory(at: placementFile.deletingLastPathComponent(), withIntermediateDirectories: true)
    try? JSONEncoder().encode(placements).write(to: placementFile, options: .atomic)
}

@MainActor func savedPlacement(windowId: UInt32, pid: Int32) -> (workspace: Workspace, isFloating: Bool)? {
    guard let placement = savedPlacements[String(windowId)], placement.pid == pid else { return nil }
    return (Workspace.get(byName: placement.workspace), placement.isFloating)
}
