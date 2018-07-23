import UIKit

class ThicknessViewController: UIViewController {
    @IBOutlet var tView: ThicknessView!
    @IBAction func highButtonPressed(_ sender: UIButton) { tView.high() }
    @IBAction func lowButtonPressed(_ sender: UIButton) { tView.low() }
    @IBAction func smoothButtonPressed(_ sender: UIButton) { tView.smooth() }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tView.setNeedsDisplay()
    }
}
