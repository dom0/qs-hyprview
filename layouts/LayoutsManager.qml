pragma Singleton
import Quickshell
import '.'

Singleton {
    id: root

    function doLayout( layoutAlgorithm, windowList, width, height, hGap, vGap, maxThumbHeight) {
        var doLayout = null
        switch (layoutAlgorithm) {
            case 'bands':
                doLayout = BandsLayout.doLayout
                break
            case 'smartgrid':
                doLayout = SmartGridLayout.doLayout
                break
            case 'spiral':
                doLayout = SpiralLayout.doLayout
                break
            case 'hero':
                doLayout = HeroLayout.doLayout
                break
            case 'masonry':
                doLayout = MasonryLayout.doLayout
                break
            case 'justified':
                doLayout = JustifiedLayout.doLayout
                break
            default:
                doLayout = SmartGridLayout.doLayout
        }

        return doLayout( windowList, width, height, hGap, vGap, maxThumbHeight)
    }
}
