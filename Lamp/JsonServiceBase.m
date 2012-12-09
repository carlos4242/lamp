//
//  JsonServiceBase.m
//  Friend Finder
//
//  Created by Carl Peto on 11/04/2012.
//  Copyright (c) 2012 Petosoft. All rights reserved.
//

#import "JsonServiceBase.h"
#import "SBJSON.h"
#import "Constants.h"
#import "Logger.h"

@interface ServiceBase (Private)
-(void)handleErrorsInCompletedResult:(NSString**)lastErrorParsed;
-(void)parseErrorCompletionOfService:(NSString**)lastErrorParsed;
-(void)handleWarningsInCompletedResult;
@end

@implementation JsonServiceBase

@synthesize output;
@synthesize completionGracePeriod = _completionGracePeriod;
@synthesize completionIsEssential = _completionIsEssential;

-(id)init {
    self = [super init];
    if (self) {
        // register to detect transition to background and extend if essential
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(enteringBackground)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];
        _completionIsEssential = NO;
        _completionGracePeriod = 40; // 40 second default
    }
    return self;
}

-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [output release];
    [super dealloc];
}
-(void)enteringBackground {
    // check if we must keep running
    if (inProgress&&_completionIsEssential ) {
        LOGGER(@"application is entering background with crucial service still in progress, asking for %d more seconds",_completionGracePeriod);
        
        _backgroundTaskIdentifier = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
            // Clean up any unfinished task business by marking where you.
            // stopped or ending the task outright.
            LOGGER(@"background task time expired (force exit by system)");
            
            [[UIApplication sharedApplication] endBackgroundTask:_backgroundTaskIdentifier];
            _backgroundTaskIdentifier = UIBackgroundTaskInvalid;
        }];
        
        // Start the long-running task and return immediately.
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{ 
            int maxCount = 0;
            // Do the work associated with the task, preferably in chunks.
            while (inProgress&&maxCount<_completionGracePeriod) {
                sleep(1);
                maxCount++;
            }
            
            LOGGER(@"background task time expired, in progress flag is %d",inProgress);
            
            [[UIApplication sharedApplication] endBackgroundTask:_backgroundTaskIdentifier];
            _backgroundTaskIdentifier = UIBackgroundTaskInvalid;
        });
    }
}
-(void)loginRequired {
    //[[NSNotificationCenter defaultCenter] postNotificationName:LOGIN_REQUIRED_NOTIFICATION object:self];
}
-                (void)connection:(NSURLConnection *)connection
didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
	if ([challenge previousFailureCount]<3) {
        [self loginRequired];
    } else {
		authFailed = YES;
		[[challenge sender] cancelAuthenticationChallenge:challenge];
	}
}
+(BOOL)validLoginCredentialsExistForJsonServices {
    NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:[NSURL URLWithString:serviceRoot]];
    for (NSHTTPCookie *cookie in cookies) {
        if ([cookie.name isEqualToString:@"username"]) {
            return YES;
        }
    }
    return NO;
}
+(void)storeFacebookAccessTokenCookie:(NSString*)access_token
                          withTimeout:(NSDate*)timeout {
    NSDictionary *access_token_parameters = [NSDictionary dictionaryWithObjectsAndKeys:
#if (DEBUG)
                                             @"staging.petosoft.com",NSHTTPCookieDomain,
#else
                                             @"www.petosoft.com",NSHTTPCookieDomain,
#endif
                                             @"/FL/API", NSHTTPCookiePath,  // IMPORTANT!
                                             @"access_token",NSHTTPCookieName,
                                             access_token,NSHTTPCookieValue,nil];

    NSHTTPCookie *cookie = [NSHTTPCookie cookieWithProperties:access_token_parameters];
    [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookie:cookie];

    NSDictionary *access_token_timeout_parameters = [NSDictionary dictionaryWithObjectsAndKeys:
#if (DEBUG)
                                                     @"staging.petosoft.com",NSHTTPCookieDomain,
#else
                                                     @"www.petosoft.com",NSHTTPCookieDomain,
#endif
                                                     @"/FL/API", NSHTTPCookiePath,  // IMPORTANT!
                                                     @"fbtokentimeout",NSHTTPCookieName,
                                                     [NSString stringWithFormat:@"%.0f",[timeout timeIntervalSince1970]],NSHTTPCookieValue,
                                                     nil];
    [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookie:[NSHTTPCookie cookieWithProperties:access_token_timeout_parameters]];
}
+(void)removeFacebookAccessTokenCookie {
    NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:[NSURL URLWithString:serviceRoot]];
    for (NSHTTPCookie *cookie in cookies) {
        if ([cookie.name isEqualToString:@"access_token"]||[cookie.name isEqualToString:@"fbtokentimeout"]) {
            [[NSHTTPCookieStorage sharedHTTPCookieStorage] deleteCookie:cookie];
        }
    }
}
+(BOOL)facebookAccessTokenCookieExists {
    NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:[NSURL URLWithString:serviceRoot]];
    for (NSHTTPCookie *cookie in cookies) {
        if ([cookie.name isEqualToString:@"access_token"]||[cookie.name isEqualToString:@"fbtokentimeout"]) {
            return YES;
        }
    }
    return NO;
}
-(void)setupSecurityForRequest:(NSMutableURLRequest*)urlRequest {
    // login should occur via a pre-existing cookie that's sent with the request, if it fails, auto request login cookie
}
-(void)callDelegateReportErrorForAllParsedErrors {
    if (![errors count]) return;
    if (![[errors objectAtIndex:0] respondsToSelector:@selector(initWithUTF8String:)]) return;
    [delegate reportError:[errors objectAtIndex:0] forService:self];
}
-(NSString*)firstErrorInParsedErrors {
    if (![errors count]) return @"no array error";
    if (![[errors objectAtIndex:0] respondsToSelector:@selector(initWithUTF8String:)]) return @"non string error";
    return [errors objectAtIndex:0];
}
-(void)parseSuccessfulCompletionOfService:(NSString**)lastErrorParsed {
    serviceCallResult = NO; // no answer means no
    if (serviceOutput) {
        SBJsonParser *parser = [[SBJsonParser alloc] init];
        output = [[parser objectWithString:serviceOutput] retain];
        if ([output isKindOfClass:[NSDictionary class]]) {
            NSNumber *resultValue = [output objectForKey:@"result"];
            BOOL result = [resultValue isKindOfClass:[NSNumber class]]&&[resultValue boolValue];
            NSLog(@"(%d) Result %d",serviceCallId,result);
            serviceCallResult=result;
            
            if (serviceCallResult) {
                [self serviceCompletedSuccessfully]; // this is overridden in subclasses to finalise processing of the service
            }

            NSString *errorMessage = [output objectForKey:@"error"];
            if (errorMessage) {
                serviceCallResult = NO;
                errors = [[NSArray arrayWithObject:errorMessage] retain];
                [self handleErrorsInCompletedResult:lastErrorParsed];
            }
            NSString *warningMessage = [output objectForKey:@"warning"];
            if (warningMessage) {
                warnings = [[NSArray arrayWithObject:warningMessage] retain];
                [self handleWarningsInCompletedResult];
            }
            
            BOOL handled = completionFunction&&completionFunction(serviceCallResult,*lastErrorParsed);
            
            if (!delegate&&!handled) {
                NSLog(@"service finished with no delegate set, errors and warnings will not show");
            }

            if (delegate) {
                NSLog(@"(%d) Service complete, calling the delegate with result %d",serviceCallId,serviceCallResult);
                [delegate serviceHasFinishedWithResult:serviceCallResult forService:self];
            }
        } else {
            [output release];
            output = nil;
            NSString *erroar = [NSString stringWithFormat:@"failed to parse json string %@, possible parse errors %@",serviceOutput,[parser errorTrace]];
            NSLog(@"%@",erroar);
            *lastErrorParsed = erroar;
            [self handleErrorsInCompletedResult:lastErrorParsed];
        }
        [parser release];
    }
}
-(void)parseErrorCompletionOfService:(NSString**)lastErrorParsed {
    [super parseErrorCompletionOfService:lastErrorParsed];
    if (lastStatusCode==401) {
        [self loginRequired];
    }
}
@end
