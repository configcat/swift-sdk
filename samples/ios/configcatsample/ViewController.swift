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
        
        self.client = ConfigCatClient(
            sdkKey: "PKDVCLf-Hq-h-kCzMp-L7Q/HhOWfwVtZ0mb30i9wi17GQ",
            refreshMode: mode,
            logLevel: .info // Info level logging helps to inspect the feature flag evaluation process. Remove this line to avoid too detailed logging in your application.
        )
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
