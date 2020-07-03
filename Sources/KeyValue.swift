import Foundation

public class KeyValue : NSObject {
    let key: String?
    let value: Any?
    init(key: String?, value: Any?) {
        self.key = key
        self.value = value
    }
}
