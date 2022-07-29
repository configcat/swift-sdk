import UIKit
import ConfigCat

class ViewController: UIViewController {
    
    var client: ConfigCatClient?
    var user: ConfigCatUser?
    @IBOutlet weak var label: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let mode = PollingModes.autoPoll(autoPollIntervalInSeconds: 5) {
            self.configChanged()
        }
        
        // Creating a user object to identify your user (optional).
        self.user = ConfigCatUser(identifier: "user-id", email: "configcat@example.com")
        
        self.client = ConfigCatClient(
            sdkKey: "PKDVCLf-Hq-h-kCzMp-L7Q/psuH7BGHoUmdONrzzUOY7A",
            refreshMode: mode,
            logLevel: .info // Info level logging helps to inspect the feature flag evaluation process. Remove this line to avoid too detailed logging in your application.
        )
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func configChanged() {
        self.client?.getValue(for: "string25Cat25Dog25Falcon25Horse", defaultValue: "", user: self.user) { value in
            DispatchQueue.main.sync {
                self.label.text = value
            }
        }
    }
}
