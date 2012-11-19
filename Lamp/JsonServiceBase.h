//
//  JsonServiceBase.h
//  Friend Finder
//
//  Created by Carl Peto on 11/04/2012.
//  Copyright (c) 2012 Petosoft. All rights reserved.
//

#import "ServiceBase.h"

@interface JsonServiceBase : ServiceBase {
    NSDictionary *output;
    BOOL _completionIsEssential;
    int _completionGracePeriod;
    UIBackgroundTaskIdentifier _backgroundTaskIdentifier;
}

@property (retain,readonly) NSDictionary *output;
@property (assign) BOOL completionIsEssential;
@property (assign) int completionGracePeriod;

+(BOOL)validLoginCredentialsExistForJsonServices;
+(void)storeFacebookAccessTokenCookie:(NSString*)access_token
                          withTimeout:(NSDate*)timeout;
+(void)removeFacebookAccessTokenCookie;
+(BOOL)facebookAccessTokenCookieExists;

@end
