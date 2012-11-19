//
//  LampService.m
//  Lamp
//
//  Created by Carl Peto on 19/11/2012.
//  Copyright (c) 2012 Carl Peto. All rights reserved.
//

#import "LampService.h"

@implementation LampService

-(void)setLampOnOff:(BOOL)onOff {
    lampOnOff = onOff;
    [super callService:@"lamp.php"];
}

-(NSString*)requestBody {
	return [NSString stringWithFormat:@"onOff=%@",lampOnOff?@"i":@"o"];
}

@end