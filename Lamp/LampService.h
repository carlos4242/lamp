//
//  LampService.h
//  Lamp
//
//  Created by Carl Peto on 19/11/2012.
//  Copyright (c) 2012 Carl Peto. All rights reserved.
//

#import "JsonServiceBase.h"

@interface LampService : JsonServiceBase

-(void)lampOneSetState:(BOOL)onOff;
-(void)lampTwoSetState:(BOOL)onOff;
-(void)lampThreeSetState:(BOOL)onOff;
-(void)beedoBeedoSetState:(BOOL)onOff;
-(BOOL)checkState;
-(BOOL)refreshState;
-(void)allOn;
-(void)allOff;

-(BOOL)lampOneIsOn;
-(BOOL)lampTwoIsOn;
-(BOOL)lampThreeIsOn;
-(BOOL)beedoBeedoIsOn;

+(in_addr_t)getIPAddress;

@end