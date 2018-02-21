import UIKit

//MARK: -

class SliceView: UIView {
    let viewSize:Float = 12  // -6 ... +6
    var scale:Float = 0
    var xc:CGFloat = 0

    func mapPoint(_ pt:CGPoint) -> float3 {
        var v = float3()
        v.x = Float(pt.x) * scale - viewSize/2 // centered on origin
        v.y = Float(pt.y) * scale - viewSize/2
        v.z = 0
        return v
    }
    
    func unMapPoint(_ p:float3) -> CGPoint {
        var v = CGPoint()
        v.x = xc + CGFloat(p.x / scale)
        v.y = xc + CGFloat(p.y / scale)
        return v
    }
    
    override func draw(_ rect: CGRect) {
        if scale == 0 {
            scale = viewSize / Float(bounds.width)
            xc = bounds.width / 2
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

        // size bars ------
        if shellRouteCount > 1 {
            let scl:Float = 25
            
            context?.setStrokeColor(UIColor.yellow.cgColor)
            for i in 1 ..< shellRouteCount {
                let pt = unMapPoint(shellRouteData[i].pos)
                let prev = unMapPoint(shellRouteData[i-1].pos)
                let angle = atan2f(Float(pt.y - prev.y),Float(pt.x - prev.x)) + Float.pi/2
                var p1 = pt
                p1.x += CGFloat(cosf(angle) * shellRouteData[i].size * scl)
                p1.y += CGFloat(sinf(angle) * shellRouteData[i].size * scl)
                var p2 = pt
                p2.x -= CGFloat(cosf(angle) * shellRouteData[i].size * scl)
                p2.y -= CGFloat(sinf(angle) * shellRouteData[i].size * scl)
                
                context?.move(to:p1)
                context?.addLine(to: p2)
            }
            context?.strokePath()
        }

        // route ---------
        context?.setStrokeColor(UIColor.red.cgColor)
        for i in 0 ..< shellRouteCount {
            let pt = unMapPoint(shellRouteData[i].pos)
            if i == 0 {  context?.move(to:pt) } else { context?.addLine(to: pt) }
        }
        
        context?.strokePath()
    }
    
    // MARK: Touch --------------------------
    let INITIAL_SIZE:Float = 0.1
    let MAX_SIZE:Float = 1
    let MIN_DISTANCE:Float = 0.2
    
    var sz:Float = 0
    
    func addSliceDataEntry(_ pt:CGPoint) {
        if shellRouteCount >= MAX_ROUTE { return }

        let v = mapPoint(pt)
        shellRouteData[shellRouteCount].pos = v

        if shellRouteCount == 0 {
            sz = INITIAL_SIZE
        } else {
            let last = shellRouteData[shellRouteCount-1]
            let distance = hypotf(last.pos.x - v.x, last.pos.y - v.y)
            
            if distance < MIN_DISTANCE {
                sz *= 1.2
                if sz > MAX_SIZE { sz = MAX_SIZE }
                return
            }
        }
        
        shellRouteData[shellRouteCount].size = sz
        shellRouteCount += 1

        sz *= 0.9
        if sz < INITIAL_SIZE { sz = INITIAL_SIZE }
     }
     
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        shellRouteCount = 0
        
        for touch in touches {
            addSliceDataEntry(touch.location(in: self))
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            addSliceDataEntry(touch.location(in: self))
            setNeedsDisplay()
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        seaShell.build(true)
    }
}
