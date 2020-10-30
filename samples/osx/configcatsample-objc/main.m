#import <Foundation/Foundation.h>
#import "ConfigCat-Swift.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // Initialize the ConfigCatClient with an SDK Key.
        ConfigCatClient* client = [[ConfigCatClient alloc]initWithSdkKey:@"PKDVCLf-Hq-h-kCzMp-L7Q/HhOWfwVtZ0mb30i9wi17GQ"
                                                          dataGovernance:DataGovernanceGlobal
                                                             configCache:nil
                                                           refreshMode:nil
                                        maxWaitTimeForSyncCallsInSeconds:0
                                                    sessionConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]
                                                                 baseUrl:@""];

        // Creating a user object to identify your user (optional).
        ConfigCatUser* userObject = [[ConfigCatUser alloc]initWithIdentifier:@"Some UserID"
                                                     email:@"configcat@example.com"
                                                   country:@"CountryID"
                                                    custom:@{@"version": @"1.0.0"}];
        
        NSString *featureName = @"isPOCFeatureEnabled";
        BOOL value = [client getBoolValueFor:featureName defaultValue:false user:userObject];
        NSLog(@"%@: %@", featureName, value ? @"Yes" : @"No");
    }
    return 0;
}
