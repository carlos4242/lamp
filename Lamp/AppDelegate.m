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

- (void)application:(UIApplication *)application handleWatchKitExtensionRequest:(NSDictionary *)userInfo reply:(void (^)(NSDictionary *))reply {
    LampService *lampService = [LampService new];
    __weak LampService *ls = lampService;
    lampService.completionFunction = ^(BOOL result,NSString *error) {
        if (ls) {
            reply([self resultFromService:ls]);
        } else {
            reply(@{@"problem":@"service died"});
        }
        return YES;
    };
    
    NSString *action = userInfo[@"action"];
    if ([action isEqualToString:@"refresh"]) {
        [lampService checkState];
    } else if ([action isEqualToString:@"set"]) {
        NSString *lamp = userInfo[@"lamp"];
        BOOL value = [userInfo[@"value"] boolValue];
        if ([lamp isEqualToString:@"tube"]) {
            [lampService lampTwoSetState:value];
        } else if ([lamp isEqualToString:@"round"]) {
            [lampService lampOneSetState:value];
        } else if ([lamp isEqualToString:@"corner"]) {
            [lampService lampThreeSetState:value];
        } else if ([lamp isEqualToString:@"bedo"]) {
            [lampService beedoBeedoSetState:value];
        }
    } else {
        reply(@{@"problem":@"unknown action"});
    }
}

@end