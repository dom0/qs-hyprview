pragma Singleton
import Quickshell

Singleton {
    id: root

    function doLayout(windowList, outerWidth, outerHeight, gap) {
        var N = windowList.length
        if (N === 0) return []

        var result = []

        // Area di lavoro corrente (inizialmente tutto lo schermo)
        // Se vuoi il margine del 10% per le animazioni, riduci qui:
        // var curW = outerWidth * 0.9
        // var curX = (outerWidth - curW) / 2; ... ecc
        var curX = 0
        var curY = 0
        var curW = outerWidth
        var curH = outerHeight

        for (var i = 0; i < N; i++) {
            var item = windowList[i]
            var isLast = (i === N - 1)

            // Dimensioni del bounding box per la finestra CORRENTE
            var boxW, boxH

            // Coordinate della finestra CORRENTE
            var boxX = curX
            var boxY = curY

            if (isLast) {
                // L'ultimo elemento si prende tutto lo spazio rimasto
                boxW = curW
                boxH = curH
            } else {
                // DECISIONE DI TAGLIO:
                // Tagliamo sempre il lato più lungo per mantenere le celle proporzionate
                if (curW > curH) {
                    // SPLIT VERTICALE (Sinistra / Destra)
                    // La finestra corrente prende la metà SINISTRA
                    boxW = (curW - gap) / 2
                    boxH = curH

                    // Aggiorniamo l'area di lavoro per le PROSSIME finestre
                    // Spostiamo la X a destra e riduciamo la larghezza disponibile
                    curX += boxW + gap
                    curW -= (boxW + gap)
                } else {
                    // SPLIT ORIZZONTALE (Alto / Basso)
                    // La finestra corrente prende la metà SUPERIORE
                    boxW = curW
                    boxH = (curH - gap) / 2

                    // Aggiorniamo l'area di lavoro per le PROSSIME finestre
                    // Spostiamo la Y in basso e riduciamo l'altezza disponibile
                    curY += boxH + gap
                    curH -= (boxH + gap)
                }
            }

            // --- Posizionamento della miniatura nel Box assegnato ---
            var w0 = (item.width && item.width > 0) ? item.width : 100
            var h0 = (item.height && item.height > 0) ? item.height : 100

            // Aspect Fit
            var scale = Math.min(boxW / w0, boxH / h0)
            var thumbW = w0 * scale
            var thumbH = h0 * scale

            // Centratura nel box
            result.push({
                win: item.win,
                x: boxX + (boxW - thumbW) / 2,
                y: boxY + (boxH - thumbH) / 2,
                width: thumbW,
                height: thumbH,
                // Aggiungiamo indici per eventuali effetti
                index: i,
                isBig: (i === 0) // La prima è sempre la più grande
            })
        }

        return result
    }
}
