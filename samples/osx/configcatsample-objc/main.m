@import Foundation;
@import ConfigCat;

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        
        ConfigCatClient* client = [ConfigCatClient getWithSdkKey:@"PKDVCLf-Hq-h-kCzMp-L7Q/HhOWfwVtZ0mb30i9wi17GQ" configurator:^(ConfigCatOptions* options){
            // Info level logging helps to inspect the feature flag evaluation process.
            // Use the default Warning level to avoid too detailed logging in your application.
            options.logLevel = ConfigCatLogLevelInfo;
            
            [options.hooks addOnReadyWithHandler:^(enum ClientCacheState state) {
                dispatch_semaphore_signal(semaphore);
            }];
        }];
        
        dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, (uint64_t)(5 * NSEC_PER_SEC)));
        
        // Creating a user object to identify your user (optional).
        ConfigCatUser* userObject = [[ConfigCatUser alloc]initWithIdentifier:@"<SOME USERID>"
                                                                       email:@"configcat@example.com"
                                                                     country:@"CountryID"
                                                                      custom:@{@"version": @"1.0.0"}];
        
        NSString *featureName = @"isPOCFeatureEnabled";
        
        ConfigCatClientSnapshot* snapshot = [client snapshot];
        
        BOOL value = [snapshot getBoolValueFor:featureName defaultValue:false user:userObject];
        NSLog(@"%@: %@", featureName, value ? @"Yes" : @"No");
    }
    return 0;
}
