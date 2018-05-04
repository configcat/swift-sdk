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
                                let sample: String = try! parser.parseValue(for: "keyString", json: config)
                                DispatchQueue.main.sync {
                                    self.label.text = sample
                                }
                              })
        }
        
        self.client = ConfigCatClient(apiKey: "PKDVCLf-Hq-h-kCzMp-L7Q/PaDVCFk9EpmD6sLpGLltTA", policyFactory: factory)
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

