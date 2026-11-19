import CoreGraphics

public enum Wrap {
    /// Largest distance carried across the wrap, so a fast flick lands near the edge
    /// instead of deep into the opposite side.
    public static let maxCarry: CGFloat = 24

    /// Decide whether the cursor should wrap horizontally.
    ///
    /// - Parameters:
    ///   - location: cursor position in global CoreGraphics coordinates (top-left origin).
    ///     macOS clamps this to the desktop, so at the right edge it sits at `maxX - 1`.
    ///   - deltaX: raw horizontal movement of this event (positive = rightwards).
    ///   - bounds: desktop bounds in the same coordinate space.
    /// - Returns: where to warp the cursor, or `nil` if it should not wrap.
    public static func target(location p: CGPoint, deltaX: Double, bounds b: CGRect) -> CGPoint? {
        guard !b.isNull, b.width >= 2, b.height >= 1 else { return nil }
        // Right after a wrap macOS reports one event whose delta is the jump itself
        // (about ±screen width). That isn't real motion, so never act on it.
        guard abs(deltaX) < Double(b.width) / 2 else { return nil }
        let rightEdge = b.maxX - 1
        let leftEdge = b.minX
        let y = min(max(p.y, b.minY), b.maxY - 1)
        let carry = min(max(CGFloat(abs(deltaX)), 1), maxCarry)

        if deltaX > 0, p.x >= rightEdge {
            return CGPoint(x: leftEdge + carry, y: y)
        }
        if deltaX < 0, p.x <= leftEdge {
            return CGPoint(x: rightEdge - carry, y: y)
        }
        return nil
    }

    /// Union of display rectangles (the whole desktop).
    public static func desktopBounds(_ displays: [CGRect]) -> CGRect {
        displays.reduce(CGRect.null) { $0.union($1) }
    }
}
