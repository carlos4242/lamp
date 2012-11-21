//
//  ViewController.m
//  Lamp
//
//  Created by Carl Peto on 19/11/2012.
//  Copyright (c) 2012 Carl Peto. All rights reserved.
//

#import "ViewController.h"
#import "LampService.h"
#import <QuartzCore/QuartzCore.h>

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.colors = [NSArray arrayWithObjects:(id)[UIColor clearColor].CGColor,(id)[UIColor blackColor].CGColor, nil]; //[UIColor colorWithWhite:0 alpha:0.2]
    gradient.frame = self.view.bounds;
    [self.view.layer insertSublayer:gradient atIndex:0];
}

- (IBAction)tubeLampOff:(id)sender {
    LampService *lamp = [LampService new];
    [lamp lampTwoSetState:NO];
}

- (IBAction)tubeLampOn:(id)sender {
    LampService *lamp = [LampService new];
    [lamp lampTwoSetState:YES];
}

- (IBAction)roundLampOff:(id)sender {
    LampService *lamp = [LampService new];
    [lamp lampOneSetState:NO];
}

- (IBAction)roundLampOn:(id)sender {
    LampService *lamp = [LampService new];
    [lamp lampOneSetState:YES];
}
@end
