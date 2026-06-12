import Cocoa
import ApplicationServices

let canvasWidth: CGFloat = 612
let canvasHeight: CGFloat = 354
let appVersion = "1.0.9"

let macKeyToAsset: [Int: Int] = [
    29: 0, 25: 1, 28: 2, 26: 3, 22: 4, 23: 5, 21: 6, 20: 7, 19: 8, 18: 9,
    50: 10, 35: 11, 31: 12, 34: 13, 32: 14, 16: 15, 17: 16, 15: 17,
    14: 18, 13: 19, 12: 20, 44: 21, 46: 22, 45: 23, 11: 24, 9: 25,
    8: 26, 37: 27, 40: 28, 38: 29, 4: 30, 5: 31, 3: 32, 0: 33,
    1: 34, 2: 35, 7: 36, 6: 37, 120: 38, 53: 39, 117: 40, 51: 41,
    36: 42, 49: 43, 58: 44, 61: 44, 56: 45, 60: 45, 59: 46, 62: 46,
    57: 47, 48: 48, 55: 49, 54: 49, 125: 50, 123: 51, 124: 52, 126: 53
]

let modifierMasks: [Int: CGEventFlags] = [
    57: .maskAlphaShift,
    56: .maskShift,
    60: .maskShift,
    59: .maskControl,
    62: .maskControl,
    58: .maskAlternate,
    61: .maskAlternate,
    55: .maskCommand,
    54: .maskCommand
]

let keyboardRightHand = [50: 0, 51: 1, 52: 2, 53: 3]
let standardSupportedAssets = Set(0..<50)

final class BilboView: NSView {
    let assetRoot: URL
    var mode = "keyboard"
    var statusText = ""
    var pressedKeys: [Int: (asset: Int, time: TimeInterval, expiresAt: TimeInterval)] = [:]
    var mouseButtons = Set<Int>()
    var imageCache: [String: NSImage] = [:]
    var dragStart: NSPoint?
    var mouseActivityUntil: TimeInterval = 0
    var mouseActivityToken = 0
    var keyboardActivityToken = 0

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    init(assetRoot: URL, mode: String) {
        self.assetRoot = assetRoot
        self.mode = mode
        super.init(frame: NSRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight))
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func handleKey(code: Int, down: Bool) {
        guard let asset = macKeyToAsset[code] else { return }
        if mode == "standard" && !standardSupportedAssets.contains(asset) {
            return
        }

        let now = Date().timeIntervalSinceReferenceDate
        if down {
            pressedKeys[code] = (asset, now, now + 0.18)
        } else if var existing = pressedKeys[code] {
            existing.expiresAt = max(existing.expiresAt, now + 0.10)
            pressedKeys[code] = existing
        } else {
            return
        }
        scheduleKeyboardCleanup()
        needsDisplay = true
    }

    func handleMouse(button: Int, down: Bool) {
        if down {
            mouseButtons.insert(button)
        } else {
            mouseButtons.remove(button)
        }
        needsDisplay = true
    }

    func handleMouseActivity() {
        mouseActivityToken += 1
        let token = mouseActivityToken
        mouseActivityUntil = Date().timeIntervalSinceReferenceDate + 0.2
        needsDisplay = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { [weak self] in
            guard let self, self.mouseActivityToken == token else { return }
            self.mouseActivityUntil = 0
            self.needsDisplay = true
        }
    }

    var isMouseActive: Bool {
        Date().timeIntervalSinceReferenceDate < mouseActivityUntil
    }

    func scheduleKeyboardCleanup() {
        keyboardActivityToken += 1
        let token = keyboardActivityToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self, self.keyboardActivityToken == token else { return }
            self.purgeExpiredKeys()
            self.needsDisplay = true
            if !self.pressedKeys.isEmpty {
                self.scheduleKeyboardCleanup()
            }
        }
    }

    func purgeExpiredKeys() {
        let now = Date().timeIntervalSinceReferenceDate
        pressedKeys = pressedKeys.filter { $0.value.expiresAt > now }
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        dirtyRect.fill()

        if mode == "standard" {
            drawStandardMode()
        } else {
            drawKeyboardMode()
        }

        if !statusText.isEmpty {
            drawStatus()
        }
    }

    func drawKeyboardMode() {
        let assets = currentKeyboardAssets()
        drawCustomImage("bulldog-black-markings.png")
        drawImage("keyboard/bg.png")
        if let left = assets.left {
            drawImage("keyboard/keyboard/\(left).png")
        }
        if let right = assets.right {
            drawImage("keyboard/keyboard/\(right).png")
        }
        if let left = assets.left {
            drawImage("keyboard/lefthand/\(left).png")
        } else {
            drawImage("keyboard/lefthand/leftup.png")
        }
        if let right = assets.right, let hand = keyboardRightHand[right] {
            drawImage("keyboard/righthand/\(hand).png")
        } else if isMouseActive {
            drawImage("keyboard/righthand/0.png")
        } else {
            drawImage("keyboard/righthand/rightup.png")
        }
    }

    func drawStandardMode() {
        let asset = latestPressedAsset(supported: standardSupportedAssets)
        drawCustomImage("bulldog-black-markings.png")
        drawImage("standard/mousebg.png")
        if let asset {
            drawImage("standard/keyboard/\(asset).png")
        }
        drawStandardMouse()
        if let asset {
            drawImage("standard/hand/\(asset).png")
        } else {
            drawImage("standard/up.png")
        }
    }

    func drawStandardMouse() {
        let image: String
        if mouseButtons.contains(0) {
            image = "standard/mouse_left.png"
        } else if mouseButtons.contains(1) {
            image = "standard/mouse_right.png"
        } else if !mouseButtons.isEmpty || isMouseActive {
            image = "standard/mouse_side.png"
        } else {
            image = "standard/mouse.png"
        }
        drawImage(image, x: 100, y: 186)
    }

    func currentKeyboardAssets() -> (left: Int?, right: Int?) {
        purgeExpiredKeys()
        var leftCandidates: [(TimeInterval, Int)] = []
        var rightCandidates: [(TimeInterval, Int)] = []

        for value in pressedKeys.values {
            if keyboardRightHand[value.asset] != nil {
                rightCandidates.append((value.time, value.asset))
            } else if value.asset >= 0 && value.asset <= 49 {
                leftCandidates.append((value.time, value.asset))
            }
        }

        return (
            leftCandidates.max { $0.0 < $1.0 }?.1,
            rightCandidates.max { $0.0 < $1.0 }?.1
        )
    }

    func latestPressedAsset(supported: Set<Int>) -> Int? {
        purgeExpiredKeys()
        return pressedKeys.values
            .filter { supported.contains($0.asset) }
            .max { $0.time < $1.time }?
            .asset
    }

    func drawImage(_ relativePath: String, x: CGFloat = 0, y: CGFloat = 0) {
        drawResolvedImage(assetRoot.appendingPathComponent("img").appendingPathComponent(relativePath), cacheKey: relativePath, x: x, y: y)
    }

    func drawCustomImage(_ filename: String, x: CGFloat = 0, y: CGFloat = 0) {
        drawResolvedImage(assetRoot.appendingPathComponent("custom").appendingPathComponent(filename), cacheKey: "custom/\(filename)", x: x, y: y)
    }

    func drawResolvedImage(_ url: URL, cacheKey: String, x: CGFloat, y: CGFloat) {
        let image: NSImage
        if let cached = imageCache[cacheKey] {
            image = cached
        } else if let loaded = NSImage(contentsOf: url) {
            image = loaded
            imageCache[cacheKey] = loaded
        } else {
            return
        }

        let destination = NSRect(x: x, y: y, width: image.size.width, height: image.size.height)
        let source = NSRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
        image.draw(in: destination,
                   from: source,
                   operation: .sourceOver,
                   fraction: 1.0,
                   respectFlipped: true,
                   hints: nil)
    }

    func drawStatus() {
        let rect = NSRect(x: 8, y: 8, width: canvasWidth - 16, height: 54)
        NSColor.white.setFill()
        rect.fill()
        NSColor.black.setStroke()
        NSBezierPath(rect: rect).stroke()

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.black,
            .paragraphStyle: paragraph
        ]
        statusText.draw(in: rect.insetBy(dx: 8, dy: 8), withAttributes: attrs)
    }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        handleMouse(button: 0, down: true)
        dragStart = NSPoint(x: event.locationInWindow.x, y: event.locationInWindow.y)
        window.makeKey()
        window.makeFirstResponder(self)
    }

    override func mouseUp(with event: NSEvent) {
        handleMouse(button: 0, down: false)
    }

    override func rightMouseDown(with event: NSEvent) {
        NSApplication.shared.terminate(nil)
    }

    override func mouseMoved(with event: NSEvent) {
        handleMouseActivity()
    }

    override func mouseDragged(with event: NSEvent) {
        handleMouseActivity()
        guard let window, let dragStart else { return }
        var frame = window.frame
        let point = NSEvent.mouseLocation
        frame.origin.x = point.x - dragStart.x
        frame.origin.y = point.y - (canvasHeight - dragStart.y)
        window.setFrame(frame, display: true)
    }

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "q" {
            NSApplication.shared.terminate(nil)
            return
        }
        if event.keyCode == 53 {
            NSApplication.shared.terminate(nil)
            return
        }
        handleKey(code: Int(event.keyCode), down: true)
    }

    override func keyUp(with event: NSEvent) {
        handleKey(code: Int(event.keyCode), down: false)
    }
}

final class BilboWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class EventTap {
    weak var view: BilboView?
    var tap: CFMachPort?
    var source: CFRunLoopSource?

    init(view: BilboView) {
        self.view = view
    }

    func start() -> Bool {
        let eventTypes: [CGEventType] = [
            .keyDown, .keyUp, .flagsChanged,
            .leftMouseDown, .leftMouseUp,
            .rightMouseDown, .rightMouseUp,
            .otherMouseDown, .otherMouseUp,
            .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged
        ]
        let mask = eventTypes.reduce(CGEventMask(0)) { result, type in
            result | (1 << CGEventMask(type.rawValue))
        }

        let userInfo = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        guard let createdTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let owner = Unmanaged<EventTap>.fromOpaque(userInfo).takeUnretainedValue()
                owner.handle(type: type, event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: userInfo
        ) else {
            return false
        }

        tap = createdTap
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, createdTap, 0)
        if let source {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        CGEvent.tapEnable(tap: createdTap, enable: true)
        return true
    }

    func handle(type: CGEventType, event: CGEvent) {
        DispatchQueue.main.async { [weak self] in
            guard let self, let view else { return }

            switch type {
            case .keyDown, .keyUp, .flagsChanged:
                let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
                if type == .flagsChanged {
                    let mask = modifierMasks[keyCode]
                    let isDown = mask.map { event.flags.contains($0) } ?? true
                    view.handleKey(code: keyCode, down: isDown)
                } else {
                    view.handleKey(code: keyCode, down: type == .keyDown)
                }
            case .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp:
                let button = Int(event.getIntegerValueField(.mouseEventButtonNumber))
                let isDown = type == .leftMouseDown || type == .rightMouseDown || type == .otherMouseDown
                view.handleMouse(button: button, down: isDown)
            case .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
                view.handleMouseActivity()
            default:
                break
            }
        }
    }
}

final class BilboAppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow?
    var bilboView: BilboView?
    var eventTap: EventTap?
    var permissionTimer: Timer?
    var statusClearTimer: Timer?
    var localEventMonitor: Any?
    var globalEventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let mode = parseMode()
        let assetRoot = findAssetRoot()
        let view = BilboView(assetRoot: assetRoot, mode: mode)

        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1024, height: 768)
        let rect = NSRect(
            x: max(0, screen.maxX - canvasWidth - 24),
            y: max(0, screen.minY + 24),
            width: canvasWidth,
            height: canvasHeight
        )

        let window = BilboWindow(contentRect: rect, styleMask: [.borderless], backing: .buffered, defer: false)
        window.title = "Bilbo-Chan"
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.acceptsMouseMovedEvents = true
        window.contentView = view
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(view)

        self.window = window
        self.bilboView = view
        NSApp.activate(ignoringOtherApps: true)
        installLocalEventMonitor()
        ensureAccessibility()
    }

    func parseMode() -> String {
        let args = CommandLine.arguments
        if let index = args.firstIndex(of: "--mode"), args.indices.contains(index + 1) {
            return args[index + 1] == "standard" ? "standard" : "keyboard"
        }
        return "keyboard"
    }

    func findAssetRoot() -> URL {
        let fm = FileManager.default
        let bundleAssets = Bundle.main.resourceURL?.appendingPathComponent("assets")
        let siblingAssets = Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("assets")
        let executableAssets = URL(fileURLWithPath: CommandLine.arguments[0])
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("assets")

        for candidate in [bundleAssets, siblingAssets, executableAssets].compactMap({ $0 }) {
            if fm.fileExists(atPath: candidate.appendingPathComponent("custom/bulldog-black-markings.png").path) {
                return candidate
            }
        }
        return siblingAssets
    }

    func hasListenEventAccess() -> Bool {
        if #available(macOS 10.15, *) {
            return CGPreflightListenEventAccess()
        }
        return true
    }

    func requestListenEventAccess() -> Bool {
        if #available(macOS 10.15, *) {
            return CGRequestListenEventAccess()
        }
        return true
    }

    func ensureAccessibility() {
        guard bilboView != nil else { return }
        let hasAccessibility = AXIsProcessTrusted()
        let hasInputMonitoring = hasListenEventAccess()

        if hasAccessibility {
            clearStatus()
            startEventTap()
            if !hasInputMonitoring {
                _ = requestListenEventAccess()
            }
            return
        }

        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        if !hasInputMonitoring {
            _ = requestListenEventAccess()
        }
        showStatus(
            "Bilbo-Chan solicitou permissao de Acessibilidade/Input Monitoring. Autorize no dialogo do macOS para capturar teclado e mouse.",
            timeout: 5
        )

        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
            guard let self else { return }
            if AXIsProcessTrusted() {
                timer.invalidate()
                self.permissionTimer = nil
                self.startEventTap()
                if !self.hasListenEventAccess() {
                    _ = self.requestListenEventAccess()
                }
            }
        }
    }

    func startEventTap() {
        guard eventTap == nil, let view = bilboView else { return }
        installGlobalEventMonitor()

        let tap = EventTap(view: view)
        if tap.start() {
            eventTap = tap
            clearStatus()
        } else {
            showStatus("O macOS recusou a captura global. Reabra o Bilbo-Chan e confirme Acessibilidade/Input Monitoring.")
        }
    }

    func installGlobalEventMonitor() {
        guard globalEventMonitor == nil else { return }
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [
            .keyDown, .keyUp, .flagsChanged,
            .leftMouseDown, .leftMouseUp,
            .rightMouseDown, .rightMouseUp,
            .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged
        ]) { [weak self] event in
            self?.handleKeyboardAndMouseEvent(event)
        }
    }

    func installLocalEventMonitor() {
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [
            .keyDown, .keyUp, .flagsChanged,
            .leftMouseDown, .leftMouseUp,
            .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged
        ]) { [weak self] event in
            self?.handleKeyboardAndMouseEvent(event)
            return event
        }
    }

    func handleKeyboardAndMouseEvent(_ event: NSEvent) {
        guard let view = bilboView else { return }
        switch event.type {
        case .keyDown:
            view.handleKey(code: Int(event.keyCode), down: true)
        case .keyUp:
            view.handleKey(code: Int(event.keyCode), down: false)
        case .flagsChanged:
            let mask = modifierMasks[Int(event.keyCode)]
            let isDown = mask.map { event.cgEvent?.flags.contains($0) ?? false } ?? true
            view.handleKey(code: Int(event.keyCode), down: isDown)
        case .leftMouseDown:
            view.handleMouse(button: 0, down: true)
        case .leftMouseUp:
            view.handleMouse(button: 0, down: false)
        case .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            view.handleMouseActivity()
        default:
            break
        }
    }

    func showStatus(_ message: String, timeout: TimeInterval? = nil) {
        guard let view = bilboView else { return }
        statusClearTimer?.invalidate()
        view.statusText = message
        view.needsDisplay = true

        guard let timeout else { return }
        statusClearTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
            guard let self, let view = self.bilboView, view.statusText == message else { return }
            self.clearStatus()
        }
    }

    func clearStatus() {
        statusClearTimer?.invalidate()
        statusClearTimer = nil
        bilboView?.statusText = ""
        bilboView?.needsDisplay = true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
        }
        if let globalEventMonitor {
            NSEvent.removeMonitor(globalEventMonitor)
        }
    }
}

let args = CommandLine.arguments
if args.contains("--help") || args.contains("-h") {
    print("""
    usage: Bilbo-Chan [--mode {keyboard,standard}]

    Bilbo-Chan for macOS
    """)
    exit(0)
}
if args.contains("--version") {
    print("Bilbo-Chan \(appVersion)")
    exit(0)
}

let app = NSApplication.shared
let delegate = BilboAppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
