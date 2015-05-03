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
@property UIBackgroundTaskIdentifier watchkitBackgroundTask;
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

- (void)application:(UIApplication *)application
handleWatchKitExtensionRequest:(NSDictionary *)userInfo
              reply:(void (^)(NSDictionary *))reply {
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) {
        if (!self.watchkitBackgroundTask || self.watchkitBackgroundTask == UIBackgroundTaskInvalid) {
            // run a new background task
            self.watchkitBackgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithName:@"watchkit service"
                                                                                       expirationHandler:^{
                [[UIApplication sharedApplication] endBackgroundTask:self.watchkitBackgroundTask];
            }];
        }
    }
    
    self.lampService = [LampService new];
    __weak AppDelegate *weakSelf = self;
    self.lampService.completionFunction = ^(BOOL result,NSString *error) {
        if (weakSelf) {
            reply([weakSelf resultFromService:weakSelf.lampService]);
            [[UIApplication sharedApplication] endBackgroundTask:weakSelf.watchkitBackgroundTask];
        } else {
            reply(@{@"problem":@"service died"});
            [[UIApplication sharedApplication] endBackgroundTask:weakSelf.watchkitBackgroundTask];
        }
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
    } else {
        reply(@{@"problem":@"unknown action"});
        [[UIApplication sharedApplication] endBackgroundTask:self.watchkitBackgroundTask];
    }
}

@end