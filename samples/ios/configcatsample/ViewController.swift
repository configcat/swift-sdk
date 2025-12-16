import UIKit
import ConfigCat

class ViewController: UIViewController {
    let client: ConfigCatClient = ConfigCatClient.get(
        sdkKey: "PKDVCLf-Hq-h-kCzMp-L7Q/HhOWfwVtZ0mb30i9wi17GQ") { options in

        // Info level logging helps to inspect the feature flag evaluation process.
        // Remove this line to avoid too detailed logging in your application.
        options.logLevel = .info

        // Creating a user object to identify your user (optional).
        options.defaultUser = ConfigCatUser(identifier: "user-id", email: "configcat@example.com")
    }
    @IBOutlet weak var label: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        Task {
            let result = await self.client.getValue(for: "isPOCFeatureEnabled", defaultValue: false)
            label.text = result.description
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}
