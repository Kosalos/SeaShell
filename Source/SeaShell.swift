import UIKit

struct iVertex {
    var x:Int
    var y:Int
    var z:Int
    
    init() { x = 0; y = 0; z = 0 }
    init(_ xx:Int, _ yy:Int, _ zz:Int) { x = xx; y = yy; z = zz }
}

extension Control {
    init() {
        mvp = float4x4()
        light = float3(10,10,0)
        tCount = 0
        alpha = 1
    }
}

extension TVertex {
    init(_ p:float3) {
        pos = p
        nrm = float3()
        txt = float2()
    }
}

let MAX_CS_ROUTE:Int = 200                      // max cross section route
let MAX_EX_POINTS:Int = ((MAX_CS_ROUTE*4)+10)   // max points in extrude shape
let MAX_ROUTE:Int = 250                         // max slices in route
let MAX_TRI:Int = MAX_EX_POINTS * MAX_ROUTE     // max triangles
let MAX_INDEX:Int = ((MAX_CS_ROUTE+1) * 2 ) * (MAX_ROUTE-1) + 2 * (MAX_ROUTE-2) + 1

struct ShellRouteData {
    var pos = float3()
    var size = Float()
}

var csRouteData = Array(repeating:float3(), count:MAX_CS_ROUTE)
var csRouteCount:Int = 0

var shellRouteData = Array(repeating:ShellRouteData(), count:MAX_ROUTE)
var shellRouteCount:Int = 0

var exShapeData = Array(repeating:float3(), count:MAX_EX_POINTS)  // extrude shape points
var exShapeCount:Int = 0

//MARK: -
class SeaShell {
    var tData = Array(repeating:TVertex(), count:MAX_TRI)        // vertices for display
    var iData = Array(repeating:UInt16(), count:MAX_INDEX)       // vertex indices
    var tCount:Int = 0
    var iCount:Int = 0
    var vBuffer: MTLBuffer?
    var iBuffer: MTLBuffer?
    var pSize = Float()
    var pThick = Float()
    var pZaxis = Float()
    var pTwist = Float()
    var pAlpha = Float()
    
    init() {
        iBuffer = gDevice?.makeBuffer(bytes:iData, length: MAX_INDEX * MemoryLayout<UInt16>.stride, options: MTLResourceOptions())
        vBuffer = gDevice?.makeBuffer(bytes:tData, length: MAX_TRI * MemoryLayout<TVertex>.stride, options: MTLResourceOptions())!
        reset()
    }
    
    //MARK: -
    
    func reset() {
        pThick = 0.1
        pZaxis = 0
        pTwist = 0
    }
    
    //MARK: -
    
    func shapeSmooth() {
        if shellRouteCount == 0 { return }
        for i in 1 ..< shellRouteCount-1 {
            let p1 = shellRouteData[i  ].pos
            let p2 = shellRouteData[i-1].pos
            let p3 = shellRouteData[i+1].pos
            
            shellRouteData[i].pos.x = (p1.x * 2.0 + p2.x + p3.x) / 4.0
            shellRouteData[i].pos.y = (p1.y * 2.0 + p2.y + p3.y) / 4.0
            shellRouteData[i].pos.z = (p1.z * 2.0 + p2.z + p3.z) / 4.0
        }
        
        vc.sliceView.setNeedsDisplay()
        build(false)
    }
    
    func sizeSmooth() {
        if shellRouteCount == 0 { return }
        for i in 1 ..< shellRouteCount-1 {
            let p1 = shellRouteData[i  ].size
            let p2 = shellRouteData[i-1].size
            let p3 = shellRouteData[i+1].size
            
            shellRouteData[i].size = (p1 * 5.0 + p2 + p3) / 7.0
        }
        
        vc.sliceView.setNeedsDisplay()
        build(true)
    }
    
    func alterSize(_ dir:Int) {
        if shellRouteCount == 0 { return }
        let mult:Float = (dir == 1) ? 1.05 : 0.95
        for i in 0 ..< shellRouteCount { shellRouteData[i].size *= mult }
        build(false)
    }
    
    func alterThick(_ dir:Int) {
        pThick *= (dir==1) ? 1.09 : 0.91
        build(true)
    }
    
    func alterZPosition(_ dir:Int) {
        pZaxis += Float(dir) * 0.002
        for i in 0 ..< shellRouteCount { shellRouteData[i].pos.z = Float(i) * pZaxis }
        build(false)
    }
    
    func alterTwist(_ dir:Int) {        // zorro  same as above
        if shellRouteCount == 0 { return }
        pTwist += Float(dir) * 0.002
        for i in 0 ..< shellRouteCount { shellRouteData[i].pos.z = Float(i) * pZaxis }
        build(false)
    }
    
    func scrollTextures() {
        for i in 0 ..< tCount {
            tData[i].txt.x += 0.0020
            tData[i].txt.y += 0.0024
            
            if tData[i].txt.x >= 1 { tData[i].txt.x -= 1 }
            if tData[i].txt.y >= 1 { tData[i].txt.y -= 1 }
        }
     }
    
    //MARK: -
    
    func calcIndices() {
        if exShapeCount == 0 { return }
        iCount = 0
        
        func addEntry(_ v:Int) {  iData[iCount] = UInt16(v);  iCount += 1  }

        for c in 0 ..< shellRouteCount-1 {
            addEntry(exShapeCount * (c+1))
            
            let base = c * exShapeCount
            
            for i in 0 ..< exShapeCount {
                addEntry(base + i)
                addEntry(base + i + 1 + exShapeCount)
                if i == exShapeCount-1 { iData[iCount-1] -= UInt16(exShapeCount) }
            }
            
            addEntry(base) // 2 indices = degenerate triangle to seperate this strip from the next
            addEntry(base)
            addEntry(base + exShapeCount * 2)
        }
    }
    
    
    var isBuilding:Bool = false
    
    func build(_ fullBuild:Bool) {
        // given the line defined by the array of X,Y coords in csRouteData:
        // determine circle of points that surround the line
        func determineInitialSlice() {
            var a2:Float = 0
            var p1 = float3()
            
            // calculate angle from each point to the previous one
            var tan = Array(repeating:Float(), count:MAX_CS_ROUTE)
            
            for i in 1 ..< csRouteCount {
                tan[i] = atan2f(csRouteData[i].y - csRouteData[i-1].y,csRouteData[i].x - csRouteData[i-1].x)
            }
            tan[0] = tan[1]
            
            func addExtrudeShapeEntry(_ v:float3) { exShapeData[exShapeCount] = v;  exShapeCount += 1  }
            
            exShapeCount = 0
            addExtrudeShapeEntry(csRouteData[0])
            
            for i in 1 ..< csRouteCount {
                p1.x = (csRouteData[i-1].x + csRouteData[i].x)/2.0 + cosf(tan[i] + Float.pi/2.0) * pThick
                p1.y = (csRouteData[i-1].y + csRouteData[i].y)/2.0 + sinf(tan[i] + Float.pi/2.0) * pThick
                addExtrudeShapeEntry(p1)
                
                if i < csRouteCount-1 {
                    a2 = atan2f(csRouteData[i+1].y - csRouteData[i-1].y,csRouteData[i+1].x - csRouteData[i-1].x)
                    p1.x = csRouteData[i].x + cosf(a2 + Float.pi/2.0) * pThick
                    p1.y = csRouteData[i].y + sinf(a2 + Float.pi/2.0) * pThick
                    addExtrudeShapeEntry(p1)
                }
            }
            
            addExtrudeShapeEntry(csRouteData[csRouteCount-1])
            
            for i in stride(from:csRouteCount-1, to:0, by: -1) {
                if i < csRouteCount-1 {
                    a2 = atan2f(csRouteData[i+1].y - csRouteData[i-1].y,csRouteData[i+1].x - csRouteData[i-1].x)
                    p1.x = csRouteData[i].x - cosf(a2 + Float.pi/2.0) * pThick
                    p1.y = csRouteData[i].y - sinf(a2 + Float.pi/2.0) * pThick
                    addExtrudeShapeEntry(p1)
                }
                
                p1.x = (csRouteData[i-1].x + csRouteData[i].x)/2.0 - cos(tan[i] + Float.pi/2.0) * pThick
                p1.y = (csRouteData[i-1].y + csRouteData[i].y)/2.0 - sin(tan[i] + Float.pi/2.0) * pThick
                addExtrudeShapeEntry(p1)
            }
            
            calcIndices()
        }
        
        func extrudeSeashell() {
            tCount = 0
            for cIndex in 0 ..< shellRouteCount {
                // Determine angle from previous circle origin to our origin.
                // This angle rotates the circle coordinates so shape follows mouse movements.
                var segmentAngle:Float = 0
                if cIndex > 1 { segmentAngle = atan2(shellRouteData[cIndex].pos.y - shellRouteData[cIndex-1].pos.y,shellRouteData[cIndex].pos.x - shellRouteData[cIndex-1].pos.x) }
                
                let saX:Float = sinf(segmentAngle)
                let saY:Float = -cos(segmentAngle)
                
                // add one circles' worth of points to vertex storage
                let twistAngle:Float = Float(cIndex) * pTwist
                let sa:Float = sinf(twistAngle)
                let ca:Float = cosf(twistAngle)
                
                for i in 0 ..< exShapeCount {
                    let tx = exShapeData[i].x * ca - exShapeData[i].y * sa
                    let ty = exShapeData[i].x * sa + exShapeData[i].y * ca
                    
                    tData[tCount].pos.x = shellRouteData[cIndex].pos.x + tx * shellRouteData[cIndex].size * saX
                    tData[tCount].pos.y = -(shellRouteData[cIndex].pos.y + tx * shellRouteData[cIndex].size * saY)
                    tData[tCount].pos.z = shellRouteData[cIndex].pos.z + ty * shellRouteData[cIndex].size + pZaxis * Float(cIndex)
                    tData[tCount].nrm   = normalize(tData[tCount].pos)
                    tData[tCount].txt.x = tData[tCount].nrm.x
                    tData[tCount].txt.y = tData[tCount].nrm.y
                    tCount += 1
                }
            }
        }
        
        if shellRouteCount > 0 {
            isBuilding = true
            if fullBuild { determineInitialSlice() }
        
            if csRouteCount > 0 && exShapeCount > 0 {
                extrudeSeashell()
            }
            isBuilding = false
        }
    }

    //MARK: -
    
    func render(_ renderEncoder:MTLRenderCommandEncoder) {
        if isBuilding || tCount == 0 || iCount == 0 || vBuffer == nil { return }
        
        vBuffer?.contents().copyBytes(from:tData, count:tCount * MemoryLayout<TVertex>.stride)
        iBuffer?.contents().copyBytes(from:iData, count:iCount * MemoryLayout<UInt16>.stride)
        
        renderEncoder.setVertexBuffer(vBuffer, offset: 0, index: 0)
        
        renderEncoder.drawIndexedPrimitives(type:.triangleStrip,  indexCount: iCount, indexType: MTLIndexType.uint16, indexBuffer: iBuffer!, indexBufferOffset:0)
    }
}

