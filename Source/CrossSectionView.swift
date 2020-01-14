import UIKit

class CrossSectionView: UIView {
    let viewSize:Float = 4  // -2 ... +2
    var scale:Float = 0
    var xc:CGFloat = 0
    
    func mapPoint(_ pt:CGPoint) -> simd_float3 {
        var v = simd_float3()
        v.x = Float(pt.x) * scale - viewSize/2 // centered on origin
        v.y = Float(pt.y) * scale - viewSize/2
        v.z = 0
        return v
    }

    func unMapPoint(_ p:simd_float3) -> CGPoint {
        var v = CGPoint()
        v.x = xc + CGFloat(p.x / scale)
        v.y = xc + CGFloat(p.y / scale)
        return v
    }

    override func draw(_ rect: CGRect) {
        if scale == 0 {
            scale = viewSize / Float(bounds.width)
            xc = bounds.width / 2
            if scale == 0 { return }
        }
        
        let context = UIGraphicsGetCurrentContext()

        context?.setLineWidth(1)
        context?.setStrokeColor(UIColor.darkGray.cgColor)
        context?.addRect(bounds)
        context?.move(to: CGPoint(x:0, y:bounds.height/2))
        context?.addLine(to: CGPoint(x:bounds.width, y:bounds.height/2))
        context?.move(to: CGPoint(x:bounds.width/2, y:0))
        context?.addLine(to: CGPoint(x:bounds.width/2, y:bounds.height))
        context?.strokePath()

        context?.setLineWidth(2)
        context?.setStrokeColor(UIColor.red.cgColor)

        for i in 0 ..< csRouteCount {
            let pt = unMapPoint(csRouteData[i])
            if i == 0 {  context?.move(to:pt) } else { context?.addLine(to: pt) }
        }
        
        context?.strokePath()
        
        // slice profile
        context?.setStrokeColor(UIColor.lightGray.cgColor)

        for i in 0 ... exShapeCount {
            var j = i; if j == exShapeCount { j = 0 }
            let pt = unMapPoint(exShapeData[j])
            if i == 0 { context?.move(to:pt) } else { context?.addLine(to: pt) }
        }

        context?.strokePath()
    }
    
    // MARK: Touch --------------------------
    
    func addPoint(_ pt:CGPoint) {
        if csRouteCount < MAX_CS_ROUTE {
            let v = mapPoint(pt)

            if csRouteCount > 0 {   // far enough away from previous point?
                let distance = hypotf(csRouteData[csRouteCount-1].x - v.x, csRouteData[csRouteCount-1].y - v.y)
                if distance < 0.1 { return }
            }

            csRouteData[csRouteCount] = v
            csRouteCount += 1
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        csRouteCount = 0
        vc.sliceView.setNeedsDisplay()
        
        for touch in touches {
            addPoint(touch.location(in: self))
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            addPoint(touch.location(in: self))
            setNeedsDisplay()
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        seaShell.crossSectionSmooth()
        seaShell.build(true)
        setNeedsDisplay()
    }
}

