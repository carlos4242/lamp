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
    [super callService:[NSString stringWithFormat:@"lamp.php?type=set&lamp=1&on=%d",onOff]];
}

-(void)lampTwoSetState:(BOOL)onOff {
    [super callService:[NSString stringWithFormat:@"lamp.php?type=set&lamp=2&on=%d",onOff]];
}

-(NSString*)requestBody {
	return @"dummy=1";
}

-(BOOL)lampOneIsOn {
    
}

@end