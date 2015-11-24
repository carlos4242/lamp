//
//  AppDelegate.m
//  Lamp
//
//  Created by Carl Peto on 19/11/2012.
//  Copyright (c) 2012 Carl Peto. All rights reserved.
//

#import "AppDelegate.h"
#import "LampViewController.h"
#import "LampService.h"

@interface AppDelegate ()
@property (strong) LampService *lampService;
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    NSLog(@"checking wifi reachability %d %d",[LampService onWifi],[LampService wifiReachabilityKnown]);
    return YES;
}

-(NSDictionary*)resultFromService:(LampService*)service {
    return @{@"tube":@([service lampTwoIsOn]),
             @"round":@([service lampOneIsOn]),
             @"corner":@([service lampThreeIsOn]),
             };
}

- (void)application:(UIApplication *)application handleWatchKitExtensionRequest:(NSDictionary *)userInfo
              reply:(void (^)(NSDictionary *))reply {
    __block UIBackgroundTaskIdentifier backgroundTask = UIBackgroundTaskInvalid;
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) {
        backgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithName:@"watchkit service" expirationHandler:^{
            NSLog(@"background task expired");
            [[UIApplication sharedApplication] endBackgroundTask:backgroundTask];
        }];
        NSLog(@"started background task for watchkit %lu",(unsigned long)backgroundTask);
    }
    
    BOOL onwifi = [LampService onWifi];
    BOOL wifiKnown = [LampService wifiReachabilityKnown];
    BOOL athome = [LampService onHomeNetwork];
    if ((!onwifi && wifiKnown) || !athome) {
        if (onwifi) {
            reply(@{@"problem":@"not at home"});
        } else {
            reply(@{@"problem":@"not on wifi"});
        }
        NSLog(@"background task finished cleanly (not on wifi or not at home)");
        [[UIApplication sharedApplication] endBackgroundTask:backgroundTask];
    } else {
        __weak AppDelegate *weakSelf = self;
        self.lampService = [LampService new];
        self.lampService.completionFunction = ^(BOOL result,NSString *error) {
            if (weakSelf) {
                if (result) {
                    reply([weakSelf resultFromService:weakSelf.lampService]);
                    NSLog(@"background task finished cleanly (service completed correctly)");
                } else if (error) {
                    reply(@{@"problem":error});
                    NSLog(@"background task finished with error %@",error);
                } else {
                    reply(@{@"problem":@"unknown error"});
                    NSLog(@"background task finished with unknown error");
                }
            } else {
                reply(@{@"problem":@"service died"});
                NSLog(@"background task finished cleanly (but service had died)");
            }
            [[UIApplication sharedApplication] endBackgroundTask:backgroundTask];
            return YES;
        };
        
        NSString *action = userInfo[@"action"];
        if ([action isEqualToString:@"refresh"]) {
            [_lampService checkState];
        } else if ([action isEqualToString:@"set"]) {
            NSString *lamp = userInfo[@"lamp"];
            BOOL value = [userInfo[@"value"] boolValue];
            if ([lamp isEqualToString:@"tube"]) {
                [_lampService lampTwoSetState:value];
            } else if ([lamp isEqualToString:@"round"]) {
                [_lampService lampOneSetState:value];
            } else if ([lamp isEqualToString:@"corner"]) {
                [_lampService lampThreeSetState:value];
            }
        } else if ([action isEqualToString:@"allOff"]) {
            [_lampService allOff];
        } else if ([action isEqualToString:@"allOn"]) {
            [_lampService allOn];
        } else {
            reply(@{@"problem":@"unknown action"});
            NSLog(@"background task finished cleanly (unknown service request)");
            [[UIApplication sharedApplication] endBackgroundTask:backgroundTask];
        }
    }
}

@end