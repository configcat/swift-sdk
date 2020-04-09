import UIKit
import ConfigCat

class ViewController: UIViewController {
    
    var client: ConfigCatClient?
    @IBOutlet weak var label: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let mode = PollingModes.autoPoll(autoPollIntervalInSeconds: 5) {
            self.configChanged()
        }
        
        self.client = ConfigCatClient(sdkKey: "PKDVCLf-Hq-h-kCzMp-L7Q/psuH7BGHoUmdONrzzUOY7A", refreshMode: mode)
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func configChanged() {
        DispatchQueue.main.sync {
            self.label.text = self.client?.getValue(for: "string25Cat25Dog25Falcon25Horse", defaultValue: "")
        }
    }
}
