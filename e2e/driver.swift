// E2E driver: posts real HID-level mouse events so they flow through WrapAround's event tap
// exactly like physical mouse input does.
import Foundation
import CoreGraphics
import ApplicationServices

func cursor() -> CGPoint { CGEvent(source: nil)!.location }
func bounds() -> CGRect { CGDisplayBounds(CGMainDisplayID()) }
let src = CGEventSource(stateID: .hidSystemState)

func post(_ type: CGEventType, _ p: CGPoint, dx: Double = 0, dy: Double = 0) {
    let e = CGEvent(mouseEventSource: src, mouseType: type, mouseCursorPosition: p, mouseButton: .left)!
    e.setDoubleValueField(.mouseEventDeltaX, value: dx)
    e.setDoubleValueField(.mouseEventDeltaY, value: dy)
    e.post(tap: .cghidEventTap)
    usleep(16_000)
}

/// Glide from the current cursor position to `to`, step by step, with real deltas.
func glide(to: CGPoint, type: CGEventType, steps: Int = 25) {
    var p = cursor()
    let sx = (to.x - p.x) / CGFloat(steps), sy = (to.y - p.y) / CGFloat(steps)
    for _ in 0..<steps { p = CGPoint(x: p.x + sx, y: p.y + sy); post(type, p, dx: sx, dy: sy) }
}

/// Keep pushing horizontally past the edge from wherever the cursor currently is.
func push(dx: Double, type: CGEventType, times: Int = 3) {
    for _ in 0..<times {
        let c = cursor()
        let b = bounds()
        let x = min(max(c.x + dx, b.minX), b.maxX - 1) // emulate WindowServer clamping
        post(type, CGPoint(x: x, y: c.y), dx: dx)
    }
}

let args = CommandLine.arguments.dropFirst()
switch args.first {
case "trusted":
    print(AXIsProcessTrusted())
case "pos":
    let c = cursor(); print("\(Int(c.x.rounded())) \(Int(c.y.rounded()))")
case "bounds":
    print(bounds())
case "warp":
    let a = args.dropFirst().compactMap(Double.init)
    CGWarpMouseCursorPosition(CGPoint(x: a[0], y: a[1])); CGAssociateMouseAndMouseCursorPosition(1)
    usleep(100_000); post(.mouseMoved, cursor())
case "push":   // push <dx> [times]
    let a = args.dropFirst().compactMap(Double.init)
    push(dx: a[0], type: .mouseMoved, times: a.count > 1 ? Int(a[1]) : 3)
case "drag":   // drag fromX fromY dropX dropY [dir: 1=right edge (default), -1=left edge] : press, glide to right edge, push past it, glide to drop, release
    let a = args.dropFirst().compactMap(Double.init)
    let from = CGPoint(x: a[0], y: a[1]), drop = CGPoint(x: a[2], y: a[3])
    CGWarpMouseCursorPosition(from); CGAssociateMouseAndMouseCursorPosition(1); usleep(150_000)
    post(.mouseMoved, from)
    post(.leftMouseDown, from); usleep(250_000)
    glide(to: CGPoint(x: from.x + 12, y: from.y + 4), type: .leftMouseDragged, steps: 6) // start the drag
    let dir: Double = a.count > 4 ? a[4] : 1
    glide(to: CGPoint(x: dir > 0 ? bounds().maxX - 1 : bounds().minX, y: drop.y), type: .leftMouseDragged)
    push(dx: 6 * dir, type: .leftMouseDragged, times: 4)
    let after = cursor(); print("after-edge-push \(Int(after.x)) \(Int(after.y))")
    glide(to: drop, type: .leftMouseDragged)
    usleep(400_000)
    post(.leftMouseDragged, drop, dx: 0.5); usleep(300_000)
    post(.leftMouseUp, drop)
    let end = cursor(); print("released-at \(Int(end.x)) \(Int(end.y))")
case "hotkey":  // press ⌃⌥⌘W with real modifier key down/up events (so nothing stays held)
    let mods: [(CGKeyCode, CGEventFlags)] = [(59, .maskControl), (58, .maskAlternate), (55, .maskCommand)]
    var flags: CGEventFlags = []
    func key(_ code: CGKeyCode, _ down: Bool, _ type: CGEventType? = nil) {
        let k = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: down)!
        if let type { k.type = type }
        k.flags = flags; k.post(tap: .cghidEventTap); usleep(20_000)
    }
    for (code, f) in mods { flags.insert(f); key(code, true, .flagsChanged) }
    key(13, true); key(13, false)
    for (code, f) in mods.reversed() { flags.remove(f); key(code, false, .flagsChanged) }
    usleep(300_000)
case "release-mods":  // safety: clear any held modifiers
    var flags: CGEventFlags = []
    for code: CGKeyCode in [55, 54, 58, 61, 59, 62, 56, 60] {
        let k = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: false)!
        k.type = .flagsChanged; k.flags = flags; k.post(tap: .cghidEventTap); usleep(10_000)
    }
    _ = flags; flags = []
default:
    print("usage: driver trusted|pos|bounds|warp x y|push dx [n]|drag fx fy dx dy")
}
