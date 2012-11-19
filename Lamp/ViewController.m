//
//  ViewController.m
//  Lamp
//
//  Created by Carl Peto on 19/11/2012.
//  Copyright (c) 2012 Carl Peto. All rights reserved.
//

#import "ViewController.h"
#import "LampService.h"

@implementation ViewController

- (IBAction)offSwitchTouched:(id)sender {
    LampService *lamp = [LampService new];
    [lamp setLampOnOff:NO];
}

- (IBAction)onSwitchTouched:(id)sender {
    LampService *lamp = [LampService new];
    [lamp setLampOnOff:YES];
}
@end
