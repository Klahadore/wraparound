import AppKit
import ApplicationServices
import Carbon.HIToolbox
import ServiceManagement
import os
import WrapCore

let log = Logger(subsystem: "com.klahadore.wraparound", category: "wrap")

// MARK: - Shared state (touched only on the main run loop)

final class State {
    static let shared = State()
    var enabled: Bool {
        didSet { UserDefaults.standard.set(enabled, forKey: "enabled"); onChange?() }
    }
    var bounds: CGRect = .null
    var tap: CFMachPort?
    var onChange: (() -> Void)?

    init() {
        UserDefaults.standard.register(defaults: ["enabled": true])
        enabled = UserDefaults.standard.bool(forKey: "enabled")
    }

    func refreshBounds() {
        var count: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &count)
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetActiveDisplayList(count, &ids, &count)
        bounds = Wrap.desktopBounds(ids.prefix(Int(count)).map { CGDisplayBounds($0) })
        log.notice("desktop bounds \(NSStringFromRect(self.bounds), privacy: .public) displays=\(count)")
    }
}

// MARK: - Event tap

private let tapCallback: CGEventTapCallBack = { _, type, event, _ in
    let state = State.shared
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap = state.tap { CGEvent.tapEnable(tap: tap, enable: true) }
        log.notice("event tap re-enabled after \(type.rawValue)")
        return Unmanaged.passUnretained(event)
    }
    guard state.enabled else { return Unmanaged.passUnretained(event) }

    let dx = event.getDoubleValueField(.mouseEventDeltaX)
    let loc = event.location
    if let target = Wrap.target(location: loc, deltaX: dx, bounds: state.bounds) {
        CGWarpMouseCursorPosition(target)
        // Re-couple mouse and cursor immediately so there is no post-warp freeze.
        CGAssociateMouseAndMouseCursorPosition(1)
        // Rewrite this event so apps (and drag sessions) see the new position right away.
        event.location = target
        log.notice("wrap type=\(type.rawValue) from x=\(loc.x) to x=\(target.x) y=\(target.y)")
    }
    return Unmanaged.passUnretained(event)
}

func installTap() -> Bool {
    if State.shared.tap != nil { return true }
    let types: [CGEventType] = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
    let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
    guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                      options: .defaultTap, eventsOfInterest: mask,
                                      callback: tapCallback, userInfo: nil) else {
        return false
    }
    let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
    CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
    CGEvent.tapEnable(tap: tap, enable: true)
    State.shared.tap = tap
    log.notice("event tap installed")
    return true
}

// MARK: - Global hotkey (⌃⌥⌘W) — Carbon hotkeys need no extra permission

private var hotKeyRef: EventHotKeyRef?

func installHotKey() {
    var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
    InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
        DispatchQueue.main.async {
            State.shared.enabled.toggle()
            log.notice("hotkey toggled enabled=\(State.shared.enabled)")
        }
        return noErr
    }, 1, &spec, nil, nil)
    let id = EventHotKeyID(signature: OSType(0x5752_4150), id: 1) // 'WRAP'
    let status = RegisterEventHotKey(UInt32(kVK_ANSI_W), UInt32(cmdKey | optionKey | controlKey),
                                     id, GetApplicationEventTarget(), 0, &hotKeyRef)
    if status != noErr { log.error("hotkey registration failed: \(status)") }
}

// MARK: - App / menu bar

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var item: NSStatusItem!
    let toggleItem = NSMenuItem(title: "Enabled", action: #selector(toggle), keyEquivalent: "w")
    let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLogin), keyEquivalent: "")
    let permItem = NSMenuItem(title: "Grant Accessibility Permission…", action: #selector(openAXSettings), keyEquivalent: "")
    var permTimer: Timer?

    func applicationDidFinishLaunching(_ note: Notification) {
        let state = State.shared
        state.refreshBounds()
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { _ in State.shared.refreshBounds() }

        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        toggleItem.keyEquivalentModifierMask = [.control, .option, .command]
        let menu = NSMenu()
        menu.delegate = self
        for i in [toggleItem, loginItem, permItem] { i.target = self }
        menu.addItem(toggleItem)
        menu.addItem(.separator())
        menu.addItem(loginItem)
        menu.addItem(permItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit WrapAround", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu

        state.onChange = { [weak self] in self?.refreshUI() }
        installHotKey()

        if !installTap() {
            let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(opts)
            log.notice("waiting for accessibility permission")
            permTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] t in
                if installTap() { t.invalidate(); self?.refreshUI() }
            }
        }
        refreshUI()
    }

    func refreshUI() {
        let on = State.shared.enabled
        let ready = State.shared.tap != nil
        let symbol = on && ready ? "arrow.left.arrow.right.circle.fill" : "arrow.left.arrow.right.circle"
        item.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "WrapAround")
        item.button?.appearsDisabled = !(on && ready)
        item.button?.toolTip = !ready ? "WrapAround: needs Accessibility permission"
            : on ? "WrapAround: on (⌃⌥⌘W to toggle)" : "WrapAround: off (⌃⌥⌘W to toggle)"
        toggleItem.state = on ? .on : .off
        permItem.isHidden = ready
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    func menuWillOpen(_ menu: NSMenu) { refreshUI() }

    @objc func toggle() { State.shared.enabled.toggle() }

    @objc func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            else { try SMAppService.mainApp.register() }
        } catch { log.error("login item: \(error.localizedDescription, privacy: .public)") }
        refreshUI()
    }

    @objc func openAXSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
