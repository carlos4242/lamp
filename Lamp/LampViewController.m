//
//  LampViewController.m
//  Lamp
//
//  Created by Carl Peto on 19/11/2012.
//  Copyright (c) 2012 Carl Peto. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>

#import "LampViewController.h"
#import "LampService.h"
#import "Reachability.h"

@interface LampViewController ()

@property (strong) CAGradientLayer *gradient;

@property (weak, nonatomic) IBOutlet UISwitch *tubeLampSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *roundLampSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *cornerLampSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *beedoBeedoSwitch;
@property (weak, nonatomic) IBOutlet UIButton *allOnButton;
@property (weak, nonatomic) IBOutlet UIButton *allOffButton;
@property (weak, nonatomic) IBOutlet UIView *notAtHomeView;
@property (weak, nonatomic) IBOutlet UILabel *notAtHomeLabel;
@property (weak, nonatomic) IBOutlet UILabel *turnOnWifiLabel;
@property (nonatomic) BOOL notAtHome;

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
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(refreshLampState)
                                                 name:kReachabilityChangedNotification
                                               object:nil];
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

-(void)setNotAtHome:(BOOL)notAtHome {
    if (_notAtHome != notAtHome) {
        _notAtHomeView.hidden = !notAtHome;
        _notAtHomeView.alpha = _notAtHome?1:0;
        [UIView animateWithDuration:0.2 animations:^{
            _notAtHomeView.alpha = notAtHome?1:0;
        }];
        _notAtHome = notAtHome;
    }
}

-(void)updateButtonStateFromLampService:(LampService*)lamp {
    [self setLamp1UIState:[lamp lampOneIsOn]];
    [self setLamp2UIState:[lamp lampTwoIsOn]];
    [self setLamp3UIState:[lamp lampThreeIsOn]];
    [self setFlasherUIState:[lamp beedoBeedoIsOn]];
    BOOL anyOn = [lamp lampOneIsOn] || [lamp lampTwoIsOn] || [lamp lampThreeIsOn] || [lamp beedoBeedoIsOn];
    BOOL allOn = [lamp lampOneIsOn] && [lamp lampTwoIsOn] && [lamp lampThreeIsOn];
    self.allOffButton.enabled = anyOn;
    self.allOffButton.alpha = self.allOffButton.enabled?1:0.2;
    self.allOnButton.enabled = !allOn;
    self.allOnButton.alpha = self.allOnButton.enabled?1:0.2;
}

-(void)updateButtonVisibility:(BOOL)enabled {
    CGFloat alpha = enabled?1.0:0.2;
    _roundLampSwitch.alpha = alpha;
    _tubeLampSwitch.alpha = alpha;
    _cornerLampSwitch.alpha = alpha;
    _beedoBeedoSwitch.alpha = alpha;
}

-(void)refreshLampState {
    self.notAtHome = ![LampService onHomeNetwork];
    if ([LampService onHomeNetwork]) {
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
    } else {
        _turnOnWifiLabel.hidden = [LampService onWifi];
        _notAtHomeLabel.hidden = ![LampService onWifi];
    }
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
- (IBAction)allOnPressed:(id)sender {
    LampService *lamp = [LampService new];
    __weak LampService *ls = lamp;
    lamp.completionFunction = ^(BOOL result,NSString *error) {
        if (result) {
            [self updateButtonStateFromLampService:ls];
        }
        return YES;
    };
    [lamp allOn];
}
- (IBAction)allOffPressed:(id)sender {
    LampService *lamp = [LampService new];
    __weak LampService *ls = lamp;
    lamp.completionFunction = ^(BOOL result,NSString *error) {
        if (result) {
            [self updateButtonStateFromLampService:ls];
        }
        return YES;
    };
    [lamp allOff];
}

@end