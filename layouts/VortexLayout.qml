pragma Singleton
import Quickshell

Singleton {
    id: root

    function doLayout(windowList, outerWidth, outerHeight) {
        var N = windowList.length
        if (N === 0) return []

        // Safe Area (90%)
        var contentScale = 0.90
        var useW = outerWidth * contentScale
        var useH = outerHeight * contentScale
        var offX = (outerWidth - useW) / 2
        var offY = (outerHeight - useH) / 2

        var centerX = offX + useW / 2
        var centerY = offY + useH / 2

        // Maximum radius (distance from center to the furthest edge of safe area)
        var maxRadius = Math.min(useW, useH) / 2

        var result = []

        // --- THE VORTEX CONFIGURATION ---

        var goldenAngle = Math.PI * (3 - Math.sqrt(5))

        // PARAMETER TWEAK 1: Minimum scale for the furthest items.
        // Increased from 0.3 to 0.5 to keep distant windows readable.
        var minScale = 0.4

        // PARAMETER TWEAK 2: Base size for the largest (first) item.
        // Increased from 0.4 to 0.6 (60% of screen height).
        var baseSizeFactor = 0.5

        for (var i = 0; i < N; i++) {
            var item = windowList[i]

            // Normalized position (0 to 1)
            var t = i / Math.max(1, N - 1)
            if (N === 1) t = 0

            // 1. Calculate Radius
            // We use a slightly wider spread (0.9 instead of 0.8) to accommodate larger thumbs
            var currentRadius = (maxRadius * 0.9) * Math.sqrt(t)

            // 2. Calculate Angle
            var currentAngle = i * goldenAngle

            // 3. Calculate Scale
            // Linearly interpolate between 1.0 and minScale
            var scale = 1.0 - (t * (1.0 - minScale))

            // 4. Calculate Rotation (Tilt)
            // Reduced tilt slightly to improve readability with larger sizes
            var tilt = (Math.cos(currentAngle) * 8)

            // 5. Coordinates (Polar to Cartesian)
            var cx = centerX + currentRadius * Math.cos(currentAngle)
            var cy = centerY + currentRadius * Math.sin(currentAngle)

            // 6. Dimensions (Aspect Fit)
            var w0 = (item.width > 0) ? item.width : 100
            var h0 = (item.height > 0) ? item.height : 100

            // Calculate base box size relative to screen
            var baseBoxSize = Math.min(useW, useH) * baseSizeFactor

            var aspect = w0 / h0
            var thumbW, thumbH

            if (aspect > 1) {
                thumbW = baseBoxSize * scale
                thumbH = thumbW / aspect
            } else {
                thumbH = baseBoxSize * scale
                thumbW = thumbH * aspect
            }

            result.push({
                win: item.win,
                x: cx - (thumbW / 2),
                y: cy - (thumbH / 2),
                width: thumbW,
                height: thumbH,
                rotation: tilt,
                zIndex: N - i // Stack order: First items on top
            })
        }

        return result
    }
}
