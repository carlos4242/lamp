//
//  LampService.h
//  Lamp
//
//  Created by Carl Peto on 19/11/2012.
//  Copyright (c) 2012 Carl Peto. All rights reserved.
//

#import "JsonServiceBase.h"

typedef enum : NSUInteger {
    no = 0,
    yes = 1,
    undefined = 2,
} OptionalBool;

@interface LampService : JsonServiceBase

-(void)lampOneSetState:(BOOL)onOff;
-(void)lampTwoSetState:(BOOL)onOff;
-(void)lampThreeSetState:(BOOL)onOff;
-(BOOL)checkState;
-(BOOL)refreshState;
-(void)allOn;
-(void)allOff;

-(OptionalBool)lampOneIsOn;
-(OptionalBool)lampTwoIsOn;
-(OptionalBool)lampThreeIsOn;

+(BOOL)onHomeNetwork;
+(BOOL)onWifi;
+(BOOL)arduinoReachable;
+(BOOL)wifiReachabilityKnown;
+(BOOL)arduinoReachabilityKnown;

@end