import UIKit
import MetalKit

var paceRotate = CGPoint()
var timer = Timer()
var vc:ViewController!

var control = Control()
var seaShell = SeaShell()

// used during development of rotated() layout routine to simulate other iPad sizes
//let scrnSz:[CGPoint] = [ CGPoint(x:768,y:1024), CGPoint(x:834,y:1112), CGPoint(x:1024,y:1366) ] // portrait 9.7, 10.5, 12.9" iPads
//let scrnIndex = 1
//let scrnLandscape:Bool = true

class ViewController: UIViewController{
    var pipeline1: MTLComputePipelineState!
    let queue = DispatchQueue(label: "Queue")
    lazy var device: MTLDevice! = MTLCreateSystemDefaultDevice()
    lazy var commandQueue: MTLCommandQueue! = { return self.device.makeCommandQueue() }()
    
    var rendererL: Renderer!
    var rendererR: Renderer!
    var isTextureScroll:Bool = false
    var isShapeSmooth:Bool = false
    var isSizeSmooth:Bool = false
    var isSizeChange:Int = 0
    var isThickChange:Int = 0
    var isZChange:Int = 0
    var isTwistChange:Int = 0
    var isStereo:Bool = true
    var alpha:Float = 1
    
    @IBOutlet var metalViewL: MTKView!
    @IBOutlet var metalViewR: MTKView!
    @IBOutlet var crossSectionView: CrossSectionView!
    @IBOutlet var sliceView: SliceView!
    @IBOutlet var shapeSmoothButton: UIButton!
    @IBOutlet var sizeSmoothButton: UIButton!
    @IBOutlet var changeSkinButton: UIButton!
    @IBOutlet var scrollSkinButton: UIButton!
    @IBOutlet var stereoButton: UIButton!
    @IBOutlet var helpButton: UIButton!
    @IBOutlet var szMButton: UIButton!
    @IBOutlet var szPButton: UIButton!
    @IBOutlet var thMButton: UIButton!
    @IBOutlet var thPButton: UIButton!
    @IBOutlet var zzMButton: UIButton!
    @IBOutlet var zzPButton: UIButton!
    @IBOutlet var twMButton: UIButton!
    @IBOutlet var twPButton: UIButton!
    @IBOutlet var alphaSlider: UISlider!
    @IBOutlet var alphaLegend: UILabel!
    
    @IBAction func alphaChanged(_ sender: UISlider) { alpha = sender.value }
    @IBAction func szMButtonPressed(_ sender: UIButton) { isSizeChange = -1 }
    @IBAction func szPButtonPressed(_ sender: UIButton) { isSizeChange = +1 }
    @IBAction func thMButtonPressed(_ sender: UIButton) { isThickChange = -1 }
    @IBAction func thPButtonPressed(_ sender: UIButton) { isThickChange = +1 }
    @IBAction func zzMButtonPressed(_ sender: UIButton) { isZChange = -1 }
    @IBAction func zzPButtonPressed(_ sender: UIButton) { isZChange = +1 }
    @IBAction func twMButtonPressed(_ sender: UIButton) { isTwistChange = -1 }
    @IBAction func twPButtonPressed(_ sender: UIButton) { isTwistChange = +1 }
    @IBAction func shapeSmoothButtonPressed(_ sender: UIButton) { isShapeSmooth = true }
    @IBAction func sizeSmoothButtonPressed(_ sender: UIButton) { isSizeSmooth = true }

    @IBAction func buttonReleased(_ sender: UIButton) {
        isShapeSmooth = false
        isSizeSmooth = false
        isSizeChange = 0
        isThickChange = 0
        isZChange = 0
        isTwistChange = 0
    }

    @IBAction func stereoButtonPressed(_ sender: UIButton) {
        isStereo = !isStereo
        metalViewR.isHidden = !isStereo
        screenRotated()
    }
    
    @IBAction func changeSkinButtonPressed(_ sender: UIButton) {
        rendererL.loadNextTexture()
        rendererR.loadNextTexture()
    }

    @IBAction func scrollSkinButtonPressed(_ sender: UIButton) {
        isTextureScroll = !isTextureScroll
    }
    
    //MARK: -
    
    override func viewDidLoad() {
        super.viewDidLoad()
        vc = self
        
        metalViewL.device = device; metalViewL.backgroundColor = UIColor.clear
        metalViewR.device = device; metalViewR.backgroundColor = UIColor.clear
        
        guard let newRenderer = Renderer(metalKitView: metalViewL, 0) else { print("Renderer cannot be initialized"); exit(0) }
        rendererL = newRenderer
        rendererL.mtkView(metalViewL, drawableSizeWillChange: metalViewL.drawableSize)
        metalViewL.delegate = rendererL

        guard let newRenderer2 = Renderer(metalKitView: metalViewR, 1) else { print("Renderer cannot be initialized"); exit(0) }
        rendererR = newRenderer2
        rendererR.mtkView(metalViewR, drawableSizeWillChange: metalViewR.drawableSize)
        metalViewR.delegate = rendererR

        
        timer = Timer.scheduledTimer(timeInterval:0.1, target:self, selector: #selector(timerHandler), userInfo: nil, repeats:true)
        screenRotated()
        
        seaShell.reset()
    }
    
    //MARK: -
    
    @objc func timerHandler() {
        if isShapeSmooth { seaShell.shapeSmooth() }
        if isSizeSmooth { seaShell.sizeSmooth() }
        if isTextureScroll { seaShell.scrollTextures() }
        if isSizeChange != 0 { seaShell.alterSize(isSizeChange) }
        if isThickChange != 0 { seaShell.alterThick(isThickChange) }
        if isZChange != 0 { seaShell.alterZPosition(isZChange) }
        if isTwistChange != 0 { seaShell.alterTwist(isTwistChange) }
        
        rotate(paceRotate.x,paceRotate.y)
    }
    
    //MARK:-
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: nil) { _ in
            self.screenRotated()
        }
    }
    
    @objc func screenRotated() {
        let xs:CGFloat = view.bounds.width
        let ys:CGFloat = view.bounds.height
        //let xs = scrnLandscape ? scrnSz[scrnIndex].y : scrnSz[scrnIndex].x
        //let ys = scrnLandscape ? scrnSz[scrnIndex].x : scrnSz[scrnIndex].y

        let fullWidth:CGFloat = 760
        let fullHeight:CGFloat = 240
        let left:CGFloat = (xs - fullWidth)/2
        let bys:CGFloat = 35    // button height

        var ixs = (xs - 4) / 2
        if ixs + fullHeight > ys { ixs = ys - fullHeight - 4 }
        var iys = ys - fullHeight

        if isStereo {
            let ixs = xs/2 - 1
            if iys > ixs { iys = ixs }
            metalViewL.frame = CGRect(x:0, y:0, width:ixs, height:iys)
            metalViewR.frame = CGRect(x:xs/2 + 1, y:0, width:ixs, height:iys)
        }
        else {
            ixs = xs - 4
            metalViewL.frame = CGRect(x:2, y:0, width:ixs, height:iys)
        }
        
        let by:CGFloat = iys + 10  // widget top
        var y:CGFloat = by
        var x:CGFloat = left
        let yhop:CGFloat = bys + 5
        let w1:CGFloat = 125
        let w2:CGFloat = 80

        shapeSmoothButton.frame = CGRect(x:x, y:y, width:w1, height:bys); y += yhop
        sizeSmoothButton.frame  = CGRect(x:x, y:y, width:w1, height:bys); y += yhop
        changeSkinButton.frame  = CGRect(x:x, y:y, width:w1, height:bys); y += yhop
        scrollSkinButton.frame  = CGRect(x:x, y:y, width:w1, height:bys); y += yhop
        x += w1 + 10
        y = by
        szMButton.frame = CGRect(x:x, y:y, width:w2, height:bys); y += yhop
        thMButton.frame = CGRect(x:x, y:y, width:w2, height:bys); y += yhop
        zzMButton.frame = CGRect(x:x, y:y, width:w2, height:bys); y += yhop
        twMButton.frame = CGRect(x:x, y:y, width:w2, height:bys); y += yhop
        x += w2 + 2
        y = by
        szPButton.frame = CGRect(x:x, y:y, width:w2, height:bys); y += yhop
        thPButton.frame = CGRect(x:x, y:y, width:w2, height:bys); y += yhop
        zzPButton.frame = CGRect(x:x, y:y, width:w2, height:bys); y += yhop
        twPButton.frame = CGRect(x:x, y:y, width:w2, height:bys); y += yhop
        x = left
        y = by + yhop * 4 + 10
        alphaLegend.frame  = CGRect(x:x, y:y, width:60, height:bys); x += 65
        alphaSlider.frame  = CGRect(x:x, y:y, width:90, height:bys); x += 125
        stereoButton.frame = CGRect(x:x, y:y, width:70, height:bys); x += 75
        helpButton.frame   = CGRect(x:x, y:y, width:60, height:bys)
        x += 45
        y = by
        let sz:CGFloat = 210
        crossSectionView.frame = CGRect(x:x, y:y, width:sz, height:sz); x += sz + 5
        sliceView.frame = CGRect(x:x, y:y, width:sz, height:sz)

        let hk = vc.metalViewL.bounds
        arcBall.initialize(Float(hk.size.width),Float(hk.size.height))
    }

    override var prefersStatusBarHidden: Bool { return true }
    
    //MARK: -

    func rotate(_ x:CGFloat, _ y:CGFloat) {
        let hk = vc.metalViewL.bounds
        let xc:CGFloat = hk.size.width/2
        let yc:CGFloat = hk.size.height/2
        arcBall.mouseDown(CGPoint(x: xc, y: yc))
        arcBall.mouseMove(CGPoint(x: xc - x, y: yc - y))
    }
    
    func parseTranslation(_ pt:CGPoint) {
        let scale:Float = 0.05
        translation.x = Float(pt.x) * scale
        translation.y = -Float(pt.y) * scale
    }
    
    func parseRotation(_ pt:CGPoint) {
        let scale:CGFloat = 0.1
        paceRotate.x = pt.x * scale
        paceRotate.y = pt.y * scale
    }
    
    var numberPanTouches:Int = 0
    
    @IBAction func panGesture(_ sender: UIPanGestureRecognizer) {
        let pt = sender.translation(in: self.view)
        let count = sender.numberOfTouches
        if count == 0 { numberPanTouches = 0 }  else if count > numberPanTouches { numberPanTouches = count }
        
        switch sender.numberOfTouches {
        case 1 : if numberPanTouches < 2 { parseRotation(pt) } // prevent rotation after releasing translation
        case 2 : parseTranslation(pt)
        default : break
        }
    }

    @IBAction func pinchGesture(_ sender: UIPinchGestureRecognizer) {
        let min:Float = 1
        let max:Float = 100
        translation.z *= Float(1 + (1 - sender.scale) / 10 )
        if translation.z < min { translation.z = min }
        if translation.z > max { translation.z = max }
    }
    
    @IBAction func tapGesture(_ sender: UITapGestureRecognizer) {
        paceRotate.x = 0
        paceRotate.y = 0
    }
}

//MARK: -

func fClamp(_ v:Float, _ range:float2) -> Float {
    if v < range.x { return range.x }
    if v > range.y { return range.y }
    return v
}

func fClamp(_ v:Float, _ min:Float, _ max:Float) -> Float {
    if v < min { return min }
    if v > max { return max }
    return v
}


