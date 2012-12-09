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
-(void)checkState;
-(void)refreshState;

-(BOOL)lampOneIsOn;
-(BOOL)lampTwoIsOn;

@end