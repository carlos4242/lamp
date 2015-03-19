//
//  LampViewController.m
//  Lamp
//
//  Created by Carl Peto on 19/11/2012.
//  Copyright (c) 2012 Carl Peto. All rights reserved.
//

#import "LampViewController.h"
#import "LampService.h"
#import <QuartzCore/QuartzCore.h>

@interface LampViewController ()

@property (strong) CAGradientLayer *gradient;

@property (weak, nonatomic) IBOutlet UISwitch *tubeLampSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *roundLampSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *cornerLampSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *beedoBeedoSwitch;

@end

@implementation LampViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    _gradient = [CAGradientLayer layer];
    UIColor *colour1 = [UIColor clearColor];
    UIColor *colour2 = [UIColor colorWithWhite:0.5 alpha:1];//[UIColor blackColor];
    
    _gradient.colors = [NSArray arrayWithObjects:(id)colour1.CGColor,(id)colour2.CGColor, nil];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        _gradient.frame = CGRectMake(0,0,1024,1024);
    } else {
        _gradient.frame = self.view.bounds;
    }
    [self.view.layer insertSublayer:_gradient atIndex:0];
    [self refreshLampState]; 
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(refreshLampState)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    [NSTimer scheduledTimerWithTimeInterval:10
                                     target:self
                                   selector:@selector(refreshLampState)
                                   userInfo:nil
                                    repeats:YES];
}

-(void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    _gradient.frame = self.view.bounds;
}

-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

-(void)setLamp1UIState:(BOOL)state {
    _roundLampSwitch.on = state;
}

-(void)setLamp2UIState:(BOOL)state {
    _tubeLampSwitch.on = state;
}

-(void)setLamp3UIState:(BOOL)state {
    _cornerLampSwitch.on = state;
}

-(void)setFlasherUIState:(BOOL)state {
    _beedoBeedoSwitch.on = state;
}

-(void)updateButtonStateFromLampService:(LampService*)lamp {
    [self setLamp1UIState:[lamp lampOneIsOn]];
    [self setLamp2UIState:[lamp lampTwoIsOn]];
    [self setLamp3UIState:[lamp lampThreeIsOn]];
    [self setFlasherUIState:[lamp beedoBeedoIsOn]];
}

-(void)updateButtonVisibility:(BOOL)enabled {
    CGFloat alpha = enabled?1.0:0.2;
    _roundLampSwitch.alpha = alpha;
    _tubeLampSwitch.alpha = alpha;
    _cornerLampSwitch.alpha = alpha;
    _beedoBeedoSwitch.alpha = alpha;
}

-(void)refreshLampState {
    LampService *lamp = [LampService new];
    __weak LampService *ls = lamp;
    lamp.completionFunction = ^(BOOL result,NSString *error) {
        [self updateButtonVisibility:result];
        if (result) {
            [self updateButtonStateFromLampService:ls];
        }
        return YES;
    };
    [lamp checkState];
}

- (IBAction)tubeLampChanged:(UISwitch*)sender {
    LampService *lamp = [LampService new];
    __weak LampService *ls = lamp;
    lamp.completionFunction = ^(BOOL result,NSString *error) {
        if (result) {
            [self updateButtonStateFromLampService:ls];
        }
        return YES;
    };
    [lamp lampTwoSetState:sender.on];
}

- (IBAction)roundLampChanged:(UISwitch*)sender {
    LampService *lamp = [LampService new];
    __weak LampService *ls = lamp;
    lamp.completionFunction = ^(BOOL result,NSString *error) {
        if (result) {
            [self updateButtonStateFromLampService:ls];
        }
        return YES;
    };
    [lamp lampOneSetState:sender.on];
}

- (IBAction)cornerLampChanged:(UISwitch*)sender {
    LampService *lamp = [LampService new];
    __weak LampService *ls = lamp;
    lamp.completionFunction = ^(BOOL result,NSString *error) {
        if (result) {
            [self updateButtonStateFromLampService:ls];
        }
        return YES;
    };
    [lamp lampThreeSetState:sender.on];
}

- (IBAction)beedoBeedoChanged:(UISwitch*)sender {
    LampService *lamp = [LampService new];
    __weak LampService *ls = lamp;
    lamp.completionFunction = ^(BOOL result,NSString *error) {
        if (result) {
            [self updateButtonStateFromLampService:ls];
        }
        return YES;
    };
    [lamp beedoBeedoSetState:sender.on];
}

@end