pragma Singleton
import Quickshell

Singleton {
    id: root

    function doLayout(windowList, outerWidth, outerHeight, gap) {
        if (windowList.length === 0) return []

        var result = []
        var heroW = outerWidth * 0.40; // 60% larghezza master
        var stackW = outerWidth - heroW - gap

        // 1. Posiziona la HERO (prima finestra della lista)
        var heroItem = windowList[0]
        // Aspect fit dentro l'area Hero
        var scH = Math.min(heroW / heroItem.width, outerHeight / heroItem.height)
        var hW = heroItem.width * scH
        var hH = heroItem.height * scH

        result.push({
            win: heroItem.win,
            x: (heroW - hW) / 2, // Centrata nella sua zona
            y: (outerHeight - hH) / 2,
            width: hW,
            height: hH
        })

        // 2. Posiziona le altre nello STACK (colonna a destra)
        var others = windowList.slice(1)
        if (others.length > 0) {
            var stackX = heroW + gap
            // Qui usiamo una logica semplice: una colonna verticale
            var itemH = (outerHeight - (others.length - 1) * gap) / others.length
            // O un limite massimo di altezza per non deformarle

            others.forEach(function(item, idx) {
                // Calcola scala per fittare nel box assegnato
                var sc = Math.min(stackW / item.width, itemH / item.height)
                var w = item.width * sc
                var h = item.height * sc

                // Centra nel box
                var boxY = idx * (itemH + gap)

                result.push({
                    win: item.win,
                    x: stackX + (stackW - w) / 2,
                    y: boxY + (itemH - h) / 2,
                    width: w,
                    height: h
                })
            })
        }
        return result
    }
}
