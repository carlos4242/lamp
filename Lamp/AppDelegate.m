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
    return YES;
}

-(NSDictionary*)resultFromService:(LampService*)service {
    return @{@"tube":@([service lampTwoIsOn]),
             @"round":@([service lampOneIsOn]),
             @"corner":@([service lampThreeIsOn]),
             @"bedo":@([service beedoBeedoIsOn]),
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

    self.lampService = [LampService new];
    __weak AppDelegate *weakSelf = self;
    self.lampService.completionFunction = ^(BOOL result,NSString *error) {
        if (weakSelf) {
            reply([weakSelf resultFromService:weakSelf.lampService]);
            NSLog(@"background task finished cleanly (service completed correctly)");
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
        } else if ([lamp isEqualToString:@"bedo"]) {
            [_lampService beedoBeedoSetState:value];
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

@end