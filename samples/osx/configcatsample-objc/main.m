#import <Foundation/Foundation.h>
#import "ConfigCat-Swift.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        ConfigCatClient* client = [ConfigCatClient getWithSdkKey:@"PKDVCLf-Hq-h-kCzMp-L7Q/HhOWfwVtZ0mb30i9wi17GQ" configurator:^(ConfigCatOptions* options){
            // Info level logging helps to inspect the feature flag evaluation process.
            // Use the default Warning level to avoid too detailed logging in your application.
            options.logLevel = LogLevelInfo;
        }];
        
        // Creating a user object to identify your user (optional).
        ConfigCatUser* userObject = [[ConfigCatUser alloc]initWithIdentifier:@"Some UserID"
                                                     email:@"configcat@example.com"
                                                   country:@"CountryID"
                                                    custom:@{@"version": @"1.0.0"}];
        
        NSString *featureName = @"isPOCFeatureEnabled";
        BOOL value = [client getBoolValueSyncFor:featureName defaultValue:false user:userObject];
        NSLog(@"%@: %@", featureName, value ? @"Yes" : @"No");
    }
    return 0;
}
