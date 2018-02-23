import UIKit

class ThicknessView: UIView {
    let xMargin:Float = 5
    var xScale:Float = 0
    var yScale:Float = 0

    func refresh() {
        seaShell.build(true)
        vc.refresh()
        vc.sliceView.setNeedsDisplay()
        setNeedsDisplay()
    }
    
    func setAll(_ v:Float) {
        for i in 0 ..< shellRouteCount { shellRouteData[i].size = v }
        refresh()
    }
    
    func high() { setAll(MAX_THICK) }
    func low() { setAll(MIN_THICK) }
    func smooth() { seaShell.sizeSmooth(); refresh() }
    
    func mapPoint(_ pt:CGFloat) -> Float { return (fClamp(Float(pt),xMargin,Float(bounds.width) - xMargin)) / xScale } // view X coord -> thickness
    func unMapPoint(_ index:Int, _ p:Float) -> CGPoint { return CGPoint(x:CGFloat(xMargin + p * xScale), y:CGFloat(Float(index) * yScale)) } // thickness -> view coord
    
    override func draw(_ rect: CGRect) {
        if xScale == 0 {
            xScale = (Float(bounds.width) - xMargin * 2) / MAX_THICK }

        let context = UIGraphicsGetCurrentContext()
        
        context?.setFillColor(UIColor.black.cgColor)
        context?.addRect(bounds)
        context?.fillPath()

        context?.setLineWidth(1)
        context?.setStrokeColor(UIColor.darkGray.cgColor)
        context?.addRect(bounds)
        context?.strokePath()
        
        if shellRouteCount == 0 { return }
        yScale = Float(bounds.height) / Float(shellRouteCount)

        context?.setLineWidth(2)
        context?.setStrokeColor(UIColor.yellow.cgColor)
        
        for i in 0 ..< shellRouteCount {
            let pt = unMapPoint(i,shellRouteData[i].size)
            if i == 0 {  context?.move(to:pt) } else { context?.addLine(to: pt) }
        }
        
        context?.strokePath()
    }
    
    // MARK:-
  
    var lastY:CGFloat = 0
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let pt = touch.location(in: self)
            lastY = pt.y
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if shellRouteCount == 0 { return }
        
        func calcIndex(_ y:CGFloat) -> Int {
            var index = Int(Float(y) / yScale)
            if index < 0 { index = 0 } else if index >= shellRouteCount-1 { index = shellRouteCount-1 }
            return index
        }

        for touch in touches {
            let pt = touch.location(in: self)
            let index = calcIndex(pt.y)
            
            let lastIndex = calcIndex(lastY)
            let lastSize = shellRouteData[lastIndex].size
            let newSize = mapPoint(pt.x)
            let sizeDiff = newSize - lastSize
            let yDiff = (pt.y - lastY) / 20
            var y = lastY
            
            func yRatio() -> Float { return Float(y - lastY) / Float(pt.y - lastY) }
            
            while true {
                let dy:CGFloat = fabs(y - pt.y)
                if dy < 1 { break }
                
                let index = calcIndex(y)
                shellRouteData[index].size = lastSize + yRatio() * sizeDiff
                
                y += yDiff
            }
            
            lastY = pt.y
            refresh()
        }
    }
}
