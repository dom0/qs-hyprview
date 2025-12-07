pragma Singleton
import Quickshell

Singleton {
    id: root

    function doLayout(windowList, outerWidth, outerHeight, hGap, vGap, maxThumbH) {
        var N = windowList.length
        if (N === 0)
            return []

        var containerWidth  = outerWidth  * 0.9
        var containerHeight = outerHeight * 0.9

        if (containerWidth <= 0 || containerHeight <= 0) {
            return windowList.map(function(item) {
                return {
                    win: item.win,
                    x: 0,
                    y: 0,
                    width: 0,
                    height: 0
                }
            })
        }

        var targetRowH = maxThumbH
        var rows = []
        var currentRow = []
        var sumAspect = 0

        function flushRow() {
            if (currentRow.length === 0)
                return

            var n = currentRow.length
            var rowHeight = maxThumbH
            if (sumAspect > 0) {
                var totalGapWidth = hGap * (n - 1)
                var hFit = (containerWidth - totalGapWidth) / sumAspect
                if (hFit < rowHeight)
                    rowHeight = hFit
            }

            if (rowHeight > maxThumbH)
                rowHeight = maxThumbH
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

        for (var i = 0; i < N; ++i) {
            var item = windowList[i]
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
        for (var r = 0; r < rows.length; ++r) {
            totalRawHeight += rows[r].height
        }
        if (rows.length > 1) {
            totalRawHeight += vGap * (rows.length - 1)
        }

        var sV = 1.0
        var availH = containerHeight
        if (totalRawHeight > 0 && totalRawHeight > availH) {
            sV = availH / totalRawHeight
        }
        if (sV <= 0)
            sV = 0.1
        if (sV > 1.0)
            sV = 1.0

        var gridTotalHeightScaled = totalRawHeight * sV
        var yAcc = (outerHeight - gridTotalHeightScaled) / 2
        if (!isFinite(yAcc) || yAcc < 0)
            yAcc = 0

        var result = []

        for (var r2 = 0; r2 < rows.length; ++r2) {
            var row = rows[r2]
            var rowHeightScaled = row.height * sV

            var rowWidthNoGapsScaled = 0
            for (var j = 0; j < row.items.length; ++j) {
                rowWidthNoGapsScaled += row.items[j].aspect * rowHeightScaled
            }
            var totalRowWidthScaled = rowWidthNoGapsScaled + hGap * (row.items.length - 1)

            var xAcc = (outerWidth - totalRowWidthScaled) / 2
            if (!isFinite(xAcc))
                xAcc = 0

            for (var j2 = 0; j2 < row.items.length; ++j2) {
                var it2 = row.items[j2]
                var wScaled = it2.aspect * rowHeightScaled
                var hScaled = rowHeightScaled

                result.push({
                    win: it2.win,
                    x: xAcc,
                    y: yAcc,
                    width: wScaled,
                    height: hScaled
                })

                xAcc += wScaled + hGap
            }

            yAcc += rowHeightScaled
            if (r2 < rows.length - 1) {
                yAcc += vGap * sV
            }
        }

        return result
    }
}
