//
//  LampService.m
//  Lamp
//
//  Created by Carl Peto on 19/11/2012.
//  Copyright (c) 2012 Carl Peto. All rights reserved.
//

#import "LampService.h"

@implementation LampService

-(void)lampOneSetState:(BOOL)onOff {
    [super callService:[NSString stringWithFormat:@"lamp.php?onOff=%@",onOff?@"a":@"b"]];
}

-(void)lampTwoSetState:(BOOL)onOff {
    [super callService:[NSString stringWithFormat:@"lamp.php?onOff=%@",onOff?@"c":@"d"]];
}

-(NSString*)requestBody {
	return @"dummy=1";
}

@end