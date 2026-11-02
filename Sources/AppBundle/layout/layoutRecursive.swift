import AppKit
import Common

extension Workspace {
    @MainActor
    func layoutWorkspace() async throws {
        if isEffectivelyEmpty {
            fullscreenHolder = nil
            return
        }
        // Like Omarchy (Hyprland's on_focus_under_fullscreen = 1): the focused tiling window takes over fullscreen.
        // It also comes back when the fullscreen window floats or closes, e.g. a login popup that tiled until
        // center-browser-popup.sh floated it
        let tilingWindows = rootTilingContainer.allLeafWindowsRecursive
        let leftTiling = fullscreenHolder?.takeIf { $0.nodeWorkspace == nil || $0.nodeWorkspace == self && !tilingWindows.contains($0) }
        if let mostRecent = rootTilingContainer.mostRecentWindowRecursive,
           let holder = tilingWindows.first(where: \.isFullscreen) ?? leftTiling, holder != mostRecent
        {
            holder.isFullscreen = false
            mostRecent.isFullscreen = true
            mostRecent.noOuterGapsInFullscreen = holder.noOuterGapsInFullscreen
        }
        fullscreenHolder = tilingWindows.first(where: \.isFullscreen)
        let rect = workspaceMonitor.visibleRectPaddedByOuterGaps
        // If monitors are aligned vertically and the monitor below has smaller width, then macOS may not allow the
        // window on the upper monitor to take full width. rect.height - 1 resolves this problem
        // But I also faced this problem in monitors horizontal configuration. ¯\_(ツ)_/¯
        try await layoutRecursive(rect.topLeftCorner, width: rect.width, height: rect.height - 1, virtual: rect, LayoutContext(self))
    }
}

extension TreeNode {
    @MainActor
    fileprivate func layoutRecursive(_ point: CGPoint, width: CGFloat, height: CGFloat, virtual: Rect, _ context: LayoutContext) async throws {
        let physicalRect = Rect(topLeftX: point.x, topLeftY: point.y, width: width, height: height)
        switch nodeCases {
            case .workspace(let workspace):
                lastAppliedLayoutPhysicalRect = physicalRect
                lastAppliedLayoutVirtualRect = virtual
                try await workspace.rootTilingContainer.layoutRecursive(point, width: width, height: height, virtual: virtual, context)
                try await workspace.floatingWindowsContainer.layoutRecursive(point, width: width, height: height, virtual: virtual, context)
            case .floatingWindowsContainer(let container):
                for window in container.children.filterIsInstance(of: Window.self) {
                    window.lastAppliedLayoutPhysicalRect = nil
                    window.lastAppliedLayoutVirtualRect = nil
                    try await window.layoutFloatingWindow(context)
                }
            case .window(let window):
                if window.windowId != currentlyManipulatedWithMouseWindowId {
                    lastAppliedLayoutVirtualRect = virtual
                    if window.isFullscreen && window == context.workspace.rootTilingContainer.mostRecentWindowRecursive {
                        lastAppliedLayoutPhysicalRect = nil
                        window.layoutFullscreen(context)
                    } else {
                        lastAppliedLayoutPhysicalRect = physicalRect
                        window.isFullscreen = false
                        window.setAxFrame(point, CGSize(width: width, height: height))
                    }
                }
            case .tilingContainer(let container):
                lastAppliedLayoutPhysicalRect = physicalRect
                lastAppliedLayoutVirtualRect = virtual
                switch container.layout {
                    case .tiles:
                        try await container.layoutTiles(point, width: width, height: height, virtual: virtual, context)
                    case .accordion:
                        try await container.layoutAccordion(point, width: width, height: height, virtual: virtual, context)
                }
            case .macosMinimizedWindowsContainer, .macosFullscreenWindowsContainer,
                 .macosPopupWindowsContainer, .macosHiddenAppsWindowsContainer:
                return // Nothing to do for weirdos
        }
    }
}

/// Splits `total` proportionally to `weights`, but gives every child at least its minimum. Expects the minimums to fit
private func distribute(_ total: CGFloat, weights: [CGFloat], mins: [CGFloat]) -> [CGFloat] {
    var atMin = Set<Int>()
    while true {
        let free = weights.indices.filter { !atMin.contains($0) }
        let rest = total - atMin.map { mins[$0] }.reduce(0, +)
        let freeWeight = free.map { weights[$0] }.reduce(0, +)
        let sizes = weights.indices.map { i in
            atMin.contains(i) ? mins[i] : freeWeight > 0 ? weights[i] * rest / freeWeight : rest / CGFloat(free.count)
        }
        let tooSmall = free.filter { sizes[$0] < mins[$0] }
        if tooSmall.isEmpty { return sizes }
        atMin.formUnion(tooSmall)
    }
}

extension TreeNode {
    /// The smallest size along `orientation` that fits the minimum sizes of all windows, tiled side by side
    @MainActor
    fileprivate func tilingMinSize(_ orientation: Orientation, _ context: LayoutContext) -> CGFloat {
        switch nodeCases {
            case .window(let window): window.learnedMinSize.get(orientation)
            case .tilingContainer(let container) where container.layout == .tiles && container.orientation == orientation:
                container.children.map { $0.tilingMinSize(orientation, context) }.reduce(0, +) +
                    CGFloat(container.children.count - 1) * context.resolvedGaps.inner.get(orientation).toDouble()
            case .tilingContainer(let container):
                (container.children.map { $0.tilingMinSize(orientation, context) }.max() ?? 0) + container.stackPadding(orientation)
            default: 0
        }
    }

    /// The smallest size along `orientation` that fits the minimum sizes of all windows, if containers stack
    @MainActor
    fileprivate func stackedMinSize(_ orientation: Orientation) -> CGFloat {
        switch nodeCases {
            case .window(let window): window.learnedMinSize.get(orientation)
            case .tilingContainer(let container):
                (container.children.map { $0.stackedMinSize(orientation) }.max() ?? 0) + container.stackPadding(orientation)
            default: 0
        }
    }
}

extension TilingContainer {
    /// Space that accordion layout takes from each window to show its neighbors
    @MainActor
    fileprivate func stackPadding(_ orientation: Orientation) -> CGFloat {
        self.orientation == orientation && children.count > 1 ? 2 * CGFloat(config.accordionPadding) : 0
    }
}

extension CGSize {
    fileprivate func get(_ orientation: Orientation) -> CGFloat { orientation == .h ? width : height }
}

private struct LayoutContext {
    let workspace: Workspace
    let resolvedGaps: ResolvedGaps

    @MainActor
    init(_ workspace: Workspace) {
        self.workspace = workspace
        self.resolvedGaps = ResolvedGaps(gaps: config.gaps, monitor: workspace.workspaceMonitor)
    }
}

extension Window {
    @MainActor
    fileprivate func layoutFloatingWindow(_ context: LayoutContext) async throws {
        let workspace = context.workspace
        let windowRect = try await getAxRect(.cancellable) // Probably not idempotent
        let currentMonitor = windowRect?.center.monitorApproximation
        // The second condition rescues floating windows stranded in the hide corner. It happens when the window dies
        // while hidden (screen lock, app hides its window on close) and closedWindowsCache restores it without
        // prevUnhiddenProportionalPositionInsideWorkspaceRect, so unhideFromCorner has nothing to restore
        let isStranded = currentMonitor.map { windowRect?.isStranded(outside: $0.visibleRect) == true } ?? false
        if let currentMonitor, let windowRect, workspace != currentMonitor.activeWorkspace || isStranded {
            let workspaceRect = workspace.workspaceMonitor.visibleRect
            var newX: CGFloat
            var newY: CGFloat
            if isStranded { // The previous position is lost. Mapping the corner position would push it to the bottom right
                let center = workspaceRect.topLeftToCenter(windowRect.size)
                newX = center.x
                newY = center.y
            } else {
                let windowTopLeftCorner = windowRect.topLeftCorner
                let xProportion = (windowTopLeftCorner.x - currentMonitor.visibleRect.topLeftX) / currentMonitor.visibleRect.width
                let yProportion = (windowTopLeftCorner.y - currentMonitor.visibleRect.topLeftY) / currentMonitor.visibleRect.height
                newX = workspaceRect.topLeftX + xProportion * workspaceRect.width
                newY = workspaceRect.topLeftY + yProportion * workspaceRect.height
            }

            let windowWidth = windowRect.width
            let windowHeight = windowRect.height
            newX = newX.coerce(in: workspaceRect.minX ... max(workspaceRect.minX, workspaceRect.maxX - windowWidth))
            newY = newY.coerce(in: workspaceRect.minY ... max(workspaceRect.minY, workspaceRect.maxY - windowHeight))

            setAxFrame(CGPoint(x: newX, y: newY), nil)
        }
        if isFullscreen {
            layoutFullscreen(context)
            isFullscreen = false
        }
    }

    @MainActor
    fileprivate func layoutFullscreen(_ context: LayoutContext) {
        let monitorRect = noOuterGapsInFullscreen
            ? context.workspace.workspaceMonitor.visibleRect
            : context.workspace.workspaceMonitor.visibleRectPaddedByOuterGaps
        setAxFrame(monitorRect.topLeftCorner, CGSize(width: monitorRect.width, height: monitorRect.height))
    }
}

extension TilingContainer {
    @MainActor
    fileprivate func layoutTiles(_ point: CGPoint, width: CGFloat, height: CGFloat, virtual: Rect, _ context: LayoutContext) async throws {
        var point = point
        var virtualPoint = virtual.topLeftCorner

        let total = orientation == .h ? width : height
        guard let delta = (total - CGFloat(children.sumOfDouble { $0.getWeight(orientation) }))
            .div(children.count) else { return }
        for child in children {
            child.setWeight(orientation, child.getWeight(orientation) + delta)
        }

        let lastIndex = children.indices.last
        let rawGap = context.resolvedGaps.inner.get(orientation).toDouble()
        // Gaps. Consider 4 cases:
        // 1. Multiple children. Layout first child
        // 2. Multiple children. Layout last child
        // 3. Multiple children. Layout child in the middle
        // 4. Single child
        let gaps = children.indices.map { i in rawGap - (i == 0 ? rawGap / 2 : 0) - (i == lastIndex ? rawGap / 2 : 0) }
        // Unlike Hyprland, we can't force a size on macOS apps. Make room for their minimum sizes. If they don't fit even
        // when nested containers stack, stack this container
        let weights = children.map { CGFloat($0.getWeight(orientation)) }
        func sizes(_ mins: [CGFloat]) -> [CGFloat]? {
            let mins = zip(mins, gaps).map { $0 + CGFloat($1) }
            return mins.reduce(0, +) <= total ? distribute(total, weights: weights, mins: mins) : nil
        }
        guard let sizes = sizes(children.map { $0.tilingMinSize(orientation, context) })
            ?? sizes(children.map { $0.stackedMinSize(orientation) })
        else {
            try await layoutAccordion(point, width: width, height: height, virtual: virtual, context)
            return
        }

        for (i, child) in children.enumerated() {
            let size = sizes[i]
            try await child.layoutRecursive(
                i == 0 ? point : point.addingOffset(orientation, rawGap / 2),
                width: orientation == .h ? size - gaps[i] : width,
                height: orientation == .v ? size - gaps[i] : height,
                virtual: Rect(
                    topLeftX: virtualPoint.x,
                    topLeftY: virtualPoint.y,
                    width: orientation == .h ? size : width,
                    height: orientation == .v ? size : height,
                ),
                context,
            )
            virtualPoint = virtualPoint.addingOffset(orientation, size)
            point = point.addingOffset(orientation, size)
        }
    }

    @MainActor
    fileprivate func layoutAccordion(_ point: CGPoint, width: CGFloat, height: CGFloat, virtual: Rect, _ context: LayoutContext) async throws {
        guard let mruIndex: Int = mostRecentChild?.ownIndex else { return }
        for (index, child) in children.enumerated() {
            let padding = CGFloat(config.accordionPadding)
            let (lPadding, rPadding): (CGFloat, CGFloat) = switch index {
                case 0 where children.count == 1: (0, 0)
                case 0:                           (0, padding)
                case children.indices.last:       (padding, 0)
                case mruIndex - 1:                (0, 2 * padding)
                case mruIndex + 1:                (2 * padding, 0)
                default:                          (padding, padding)
            }
            switch orientation {
                case .h:
                    try await child.layoutRecursive(
                        point + CGPoint(x: lPadding, y: 0),
                        width: width - rPadding - lPadding,
                        height: height,
                        virtual: virtual,
                        context,
                    )
                case .v:
                    try await child.layoutRecursive(
                        point + CGPoint(x: 0, y: lPadding),
                        width: width,
                        height: height - lPadding - rPadding,
                        virtual: virtual,
                        context,
                    )
            }
        }
    }
}
