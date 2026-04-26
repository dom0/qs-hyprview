pragma Singleton
import Quickshell

Singleton {
    id: root

    function doLayout(windowList, outerWidth, outerHeight) {
        var N = windowList.length
        if (N === 0) return []

        // --- Parametri di stile ---
        var gap = 25 // Spazio costante tra le miniature
        var sideMargin = outerWidth * 0.08
        var topMargin = outerHeight * 0.12
        var availableW = outerWidth - (sideMargin * 2)
        var availableH = outerHeight - (topMargin * 2)

        // --- Logica di distribuzione ---
        // Forziamo il wrap dopo 4 elementi per mantenere le miniature grandi.
        // Se N=5, avremo 2 righe (distribuite come 3 e 2).
        var maxItemsPerRow = 4
        if (N <= 3) maxItemsPerRow = N // Se poche, usiamo una riga sola
        else if (N === 4) maxItemsPerRow = 2 // 4 finestre stanno meglio 2x2
        else maxItemsPerRow = 4

        var rowCount = Math.ceil(N / maxItemsPerRow)

        // Calcoliamo l'altezza target uguale per TUTTE le righe
        var targetHeight = (availableH - (gap * (rowCount - 1))) / rowCount

        // Limite superiore: non vogliamo miniature "giganti" se c'è solo una finestra
        var maxPossibleH = outerHeight * 0.38
        if (targetHeight > maxPossibleH) targetHeight = maxPossibleH

        // 1. Prepariamo gli oggetti con le proporzioni corrette
        var items = []
        for (var i = 0; i < N; i++) {
            var win = windowList[i]
            var ratio = (win.width > 0 && win.height > 0) ? (win.width / win.height) : (16/9)
            items.push({
                win: win.win,
                width: targetHeight * ratio,
                height: targetHeight
            })
        }

        // 2. Dividiamo gli elementi nelle righe in modo bilanciato
        var rows = []
        var itemsRemaining = N
        var startIndex = 0
        for (var r = 0; r < rowCount; r++) {
            var rowSize = Math.ceil(itemsRemaining / (rowCount - r))
            rows.push(items.slice(startIndex, startIndex + rowSize))
            startIndex += rowSize
            itemsRemaining -= rowSize
        }

        // 3. Calcolo finale posizioni
        var result = []

        // Calcolo altezza totale per centratura verticale
        var totalBlockH = (rows.length * targetHeight) + ((rows.length - 1) * gap)
        var currentY = (outerHeight - totalBlockH) / 2

        for (var r = 0; r < rows.length; r++) {
            var currentRow = rows[r]

            // Calcolo larghezza riga
            var rowWidth = 0
            for (var j = 0; j < currentRow.length; j++) {
                rowWidth += currentRow[j].width
            }
            rowWidth += (currentRow.length - 1) * gap

            // Se la riga è troppo larga per lo schermo, scalo tutta la riga (e l'altezza)
            var rowScale = 1.0
            if (rowWidth > availableW) {
                rowScale = availableW / rowWidth
            }

            var actualRowWidth = rowWidth * rowScale
            var currentX = (outerWidth - actualRowWidth) / 2

            for (var j = 0; j < currentRow.length; j++) {
                var item = currentRow[j]
                var finalW = item.width * rowScale
                var finalH = item.height * rowScale

                // Allineamento alla base della riga (tipico Win11)
                var yOffset = (targetHeight - finalH) / 2

                result.push({
                    win: item.win,
                    x: currentX,
                    y: currentY + yOffset,
                    width: finalW,
                    height: finalH
                })

                currentX += finalW + (gap * rowScale)
            }
            currentY += targetHeight + gap
        }

        return result
    }
}
