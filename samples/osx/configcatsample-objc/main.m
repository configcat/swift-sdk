#import <Foundation/Foundation.h>
#import "ConfigCat-Swift.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        ConfigCatClient* client = [[ConfigCatClient alloc]initWithApiKey:@"PKDVCLf-Hq-h-kCzMp-L7Q/psuH7BGHoUmdONrzzUOY7A"
                                                             configCache:nil
                                                           policyFactory:nil
                                        maxWaitTimeForSyncCallsInSeconds:0
                                                    sessionConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]
                                                                 baseUrl:@""];

        NSString *featureName = @"keySampleText";
        NSString *feature = [client getStringValueFor:featureName defaultValue:@"default"];
        NSLog(@"%@: %@ ", featureName, feature);
    }
    return 0;
}
