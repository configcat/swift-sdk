import UIKit
import ConfigCat

class ViewController: UIViewController {
    
    var client: ConfigCatClient?
    @IBOutlet weak var label: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.client = ConfigCatClient.get(
            sdkKey: "PKDVCLf-Hq-h-kCzMp-L7Q/psuH7BGHoUmdONrzzUOY7A") { options in
            options.pollingMode = PollingModes.autoPoll(autoPollIntervalInSeconds: 5)
            options.hooks.addOnConfigChanged { _ in
                self.configChanged()
            }

            // Info level logging helps to inspect the feature flag evaluation process.
            // Remove this line to avoid too detailed logging in your application.
            options.logLevel = .info

            // Creating a user object to identify your user (optional).
            options.defaultUser = ConfigCatUser(identifier: "user-id", email: "configcat@example.com")
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func configChanged() {
        self.client?.getValue(for: "string25Cat25Dog25Falcon25Horse", defaultValue: "") { value in
            DispatchQueue.main.sync {
                self.label.text = value
            }
        }
    }
}
