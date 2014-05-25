//
//  ViewController.m
//  Lamp
//
//  Created by Carl Peto on 19/11/2012.
//  Copyright (c) 2012 Carl Peto. All rights reserved.
//

#import "ViewController.h"
#import "LampService.h"
#import "UIDevice+Extensions.h"
#import <QuartzCore/QuartzCore.h>

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.colors = [NSArray arrayWithObjects:(id)[UIColor clearColor].CGColor,(id)[UIColor blackColor].CGColor, nil]; //[UIColor colorWithWhite:0 alpha:0.2]
    if ([UIDevice isIpad]) {
        gradient.frame = CGRectMake(0,0,1024,1024);
    } else {
        gradient.frame = self.view.bounds;
    }
    [self.view.layer insertSublayer:gradient atIndex:0];
    [self refreshLampState]; 
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshLampState) name:UIApplicationDidBecomeActiveNotification object:nil];
    [NSTimer scheduledTimerWithTimeInterval:600 target:self selector:@selector(refreshLampState) userInfo:nil repeats:YES];
}
-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

-(void)setLamp1UIState:(BOOL)state {
    _roundLampOnButton.selected = state;
    _roundLampOffButton.selected = !state;
}

-(void)setLamp2UIState:(BOOL)state {
    _tubeLampOnButton.selected = state;
    _tubeLampOffButton.selected = !state;
}

-(void)updateButtonStateFromLampService:(LampService*)lamp {
    [self setLamp1UIState:[lamp lampOneIsOn]];
    [self setLamp2UIState:[lamp lampTwoIsOn]];
}
-(void)refreshLampState {
    LampService *lamp = [LampService new];
    __weak LampService *ls = lamp;
    lamp.completionFunction = ^(BOOL result,NSString *error) {
        if (result) {
            [self updateButtonStateFromLampService:ls];
        }
        return YES;
    };
    [lamp checkState];
}
- (IBAction)tubeLampOff:(id)sender {
    LampService *lamp = [LampService new];
    __weak LampService *ls = lamp;
    lamp.completionFunction = ^(BOOL result,NSString *error) {
        if (result) {
            [self updateButtonStateFromLampService:ls];
        }
        return YES;
    };
    [lamp lampTwoSetState:NO];
}

- (IBAction)tubeLampOn:(id)sender {
    LampService *lamp = [LampService new];
    __weak LampService *ls = lamp;
    lamp.completionFunction = ^(BOOL result,NSString *error) {
        if (result) {
            [self updateButtonStateFromLampService:ls];
        }
        return YES;
    };
    [lamp lampTwoSetState:YES];
}

- (IBAction)roundLampOff:(id)sender {
    LampService *lamp = [LampService new];
    __weak LampService *ls = lamp;
    lamp.completionFunction = ^(BOOL result,NSString *error) {
        if (result) {
            [self updateButtonStateFromLampService:ls];
        }
        return YES;
    };
    [lamp lampOneSetState:NO];
}

- (IBAction)roundLampOn:(id)sender {
    LampService *lamp = [LampService new];
    __weak LampService *ls = lamp;
    lamp.completionFunction = ^(BOOL result,NSString *error) {
        if (result) {
            [self updateButtonStateFromLampService:ls];
        }
        return YES;
    };
    [lamp lampOneSetState:YES];
}
@end
