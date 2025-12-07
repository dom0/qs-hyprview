pragma Singleton
import Quickshell

Singleton {
    id: root

    function doLayout(windowList, outerWidth, outerHeight, hGap, vGap, maxThumbH) {
        var N = windowList.length
        if (N === 0)
            return []

        var workspaceOrder = []
        var lastWs = null
        for (var i = 0; i < N; ++i) {
            var wsId = windowList[i].workspaceId
            if (workspaceOrder.length === 0 || wsId !== lastWs) {
                workspaceOrder.push(wsId)
                lastWs = wsId
            }
        }
        var bandCount = workspaceOrder.length
        if (bandCount === 0)
            return []

        var totalBandGap = vGap * (bandCount - 1)
        var bandHeight = (outerHeight - totalBandGap) / bandCount
        if (bandHeight <= 0)
            bandHeight = outerHeight / bandCount

        var result = []

        var containerWidth = outerWidth * 0.9

        function layoutBand(bandWindows, bandTopY, bandIndex) {
            var count = bandWindows.length
            if (count === 0)
                return

            var innerHeight = bandHeight * 0.8
            var localMaxThumbH = maxThumbH
            if (innerHeight > 0 && innerHeight < localMaxThumbH)
                localMaxThumbH = innerHeight
            if (localMaxThumbH <= 0)
                localMaxThumbH = maxThumbH

            var rows = []
            var currentRow = []
            var sumAspect = 0
            var targetRowH = localMaxThumbH

            function flushRow() {
                if (currentRow.length === 0)
                    return

                var n = currentRow.length
                var rowHeight = localMaxThumbH
                if (sumAspect > 0) {
                    var totalGapWidth = hGap * (n - 1)
                    var hFit = (containerWidth - totalGapWidth) / sumAspect
                    if (hFit < rowHeight)
                        rowHeight = hFit
                }

                if (rowHeight > localMaxThumbH)
                    rowHeight = localMaxThumbH
                if (rowHeight <= 0)
                    rowHeight = 1

                rows.push({
                    items: currentRow.slice(),
                    height: rowHeight,
                    sumAspect: sumAspect
                })

                currentRow = []
                sumAspect = 0
            }

            for (var i = 0; i < count; ++i) {
                var item = bandWindows[i]
                var w0 = item.width > 0 ? item.width : 1
                var h0 = item.height > 0 ? item.height : 1
                var a = w0 / h0
                item.aspect = a

                if (currentRow.length > 0 &&
                    ((sumAspect + a) * targetRowH + hGap * currentRow.length) > containerWidth) {
                    flushRow()
                }

                currentRow.push(item)
                sumAspect += a
            }

            if (currentRow.length > 0) {
                flushRow()
            }

            var totalRawHeight = 0
            var rowGap = vGap * 0.4
            for (var r = 0; r < rows.length; ++r) {
                totalRawHeight += rows[r].height
            }
            if (rows.length > 1) {
                totalRawHeight += rowGap * (rows.length - 1)
            }

            var sB = 1.0
            var innerHeightAvail = bandHeight * 0.8
            if (innerHeightAvail > 0 && totalRawHeight > innerHeightAvail) {
                sB = innerHeightAvail / totalRawHeight
            }
            if (sB <= 0)
                sB = 0.1
            if (sB > 1.0)
                sB = 1.0

            var usedHeightScaled = totalRawHeight * sB
            var bandYStart = bandTopY + (bandHeight - usedHeightScaled) / 2
            if (!isFinite(bandYStart))
                bandYStart = bandTopY

            for (var r2 = 0; r2 < rows.length; ++r2) {
                var row = rows[r2]
                var rowHeightScaled = row.height * sB

                var rowWidthNoGapsScaled = 0
                for (var j = 0; j < row.items.length; ++j) {
                    rowWidthNoGapsScaled += row.items[j].aspect * rowHeightScaled
                }
                var totalRowWidthScaled = rowWidthNoGapsScaled + hGap * (row.items.length - 1)

                var xAcc = (outerWidth - totalRowWidthScaled) / 2
                if (!isFinite(xAcc))
                    xAcc = 0

                var rowY = bandYStart

                for (var j2 = 0; j2 < row.items.length; ++j2) {
                    var it2 = row.items[j2]
                    var wScaled = it2.aspect * rowHeightScaled
                    var hScaled = rowHeightScaled

                    result.push({
                        win: it2.win,
                        x: xAcc,
                        y: rowY,
                        width: wScaled,
                        height: hScaled
                    })

                    xAcc += wScaled + hGap
                }

                bandYStart += rowHeightScaled
                if (r2 < rows.length - 1) {
                    bandYStart += rowGap * sB
                }
            }
        }

        var bandTop = 0
        for (var b = 0; b < bandCount; ++b) {
            var wsId = workspaceOrder[b]
            var bandWindows = []
            for (var i2 = 0; i2 < N; ++i2) {
                if (windowList[i2].workspaceId === wsId)
                    bandWindows.push(windowList[i2])
            }

            layoutBand(bandWindows, bandTop, b)
            bandTop += bandHeight
            if (b < bandCount - 1)
                bandTop += vGap
        }

        return result
    }
}
