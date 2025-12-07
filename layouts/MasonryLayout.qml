pragma Singleton
import Quickshell

Singleton {
    id: root

    function doLayout(windowList, outerWidth, outerHeight, gap) {
        var N = windowList.length
        if (N === 0) return []

        // Configurazione: larghezza colonna fissa (o basata su numero colonne)
        // Esempio: Vogliamo sempre circa 3 colonne, o colonne larghe min 300px
        var numCols = Math.max(1, Math.floor(outerWidth / (outerWidth / 3))); // 400px larghezza target
        var colWidth = (outerWidth - (numCols - 1) * gap) / numCols

        // Array per tracciare l'altezza corrente di ogni colonna
        var colHeights = new Array(numCols).fill(0)
        var result = []

        for (var i = 0; i < N; i++) {
            var item = windowList[i]

            // 1. Trova la colonna più "bassa" (shortest)
            var minH = Math.min.apply(null, colHeights)
            var colIdx = colHeights.indexOf(minH)

            // 2. Calcola dimensioni
            var w0 = item.width || 100
            var h0 = item.height || 100

            // Larghezza fissa (colonna), altezza proporzionale
            var scale = colWidth / w0
            var thumbH = h0 * scale

            // 3. Posiziona
            var x = colIdx * (colWidth + gap)
            var y = colHeights[colIdx]; // Y corrente della colonna

            result.push({
                win: item.win,
                x: x,
                y: y,
                width: colWidth,
                height: thumbH,
                colIndex: colIdx
            })

            // 4. Aggiorna altezza colonna (+ gap per il prossimo elemento)
            colHeights[colIdx] += thumbH + gap
        }

        // Opzionale: Centratura verticale dell'intero blocco se le colonne sono corte
        var maxH = Math.max.apply(null, colHeights)
        var offsetY = (outerHeight - maxH) / 2
        result.forEach(function(r) { r.y += offsetY; })

        return result
    }
}
