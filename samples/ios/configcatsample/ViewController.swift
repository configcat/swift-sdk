import UIKit
import ConfigCat

class ViewController: UIViewController {
    
    var client: ConfigCatClient?
    @IBOutlet weak var label: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let factory = { (cache: ConfigCache, fetcher: ConfigFetcher) -> RefreshPolicy in
            AutoPollingPolicy(cache: cache,
                              fetcher: fetcher,
                              autoPollIntervalInSeconds: 5,
                              onConfigChanged: { (config, parser) in
                                let user = User(identifier: "key")
                                let sample: String = try! parser.parseValue(for: "string25Cat25Dog25Falcon25Horse", json: config, user: user)
                                DispatchQueue.main.sync {
                                    self.label.text = sample
                                }
                              })
        }
        
        self.client = ConfigCatClient(apiKey: "PKDVCLf-Hq-h-kCzMp-L7Q/psuH7BGHoUmdONrzzUOY7A", policyFactory: factory)
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

