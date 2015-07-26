//
//  InterfaceController.m
//  Lamp WatchKit Extension
//
//  Created by Carl Peto on 19/03/2015.
//  Copyright (c) 2015 Carl Peto. All rights reserved.
//

#import "InterfaceController.h"
#import "LampService.h"

@interface InterfaceController()

@property (weak, nonatomic) IBOutlet WKInterfaceSwitch *tubeSwitch;
@property (weak, nonatomic) IBOutlet WKInterfaceSwitch *roundSwitch;
@property (weak, nonatomic) IBOutlet WKInterfaceSwitch *cornerSwitch;
@property (weak, nonatomic) IBOutlet WKInterfaceLabel *errorLabel;

@property (weak, nonatomic) IBOutlet WKInterfaceButton *allOffSwitch;
@property (weak, nonatomic) IBOutlet WKInterfaceButton *allOnSwitch;

@property BOOL awoke,tube,round,corner;

@end


@implementation InterfaceController

-(void)setSwitchesEnabled:(BOOL)enabled {
    [self.tubeSwitch setEnabled:enabled];
    [self.roundSwitch setEnabled:enabled];
    [self.cornerSwitch setEnabled:enabled];
    [self.allOnSwitch setEnabled:enabled];
    [self.allOffSwitch setEnabled:enabled];
    [self.tubeSwitch setAlpha:enabled?1:0.2];
    [self.roundSwitch setAlpha:enabled?1:0.2];
    [self.cornerSwitch setAlpha:enabled?1:0.2];
    [self.allOnSwitch setAlpha:enabled?1:0.2];
    [self.allOffSwitch setAlpha:enabled?1:0.2];}

-(void)setSwitchesHidden:(BOOL)hidden {
    [self.tubeSwitch setHidden:hidden];
    [self.roundSwitch setHidden:hidden];
    [self.cornerSwitch setHidden:hidden];
    [self.allOnSwitch setHidden:hidden];
    [self.allOffSwitch setHidden:hidden];
}

-(void)showErrorMessage:(NSString*)message {
    [self setSwitchesHidden:message];
    [self.errorLabel setHidden:!message];
    [self.errorLabel setText:message];
}

-(void)refreshSwitchesEnable:(BOOL)enable {
    [WKInterfaceController openParentApplication:@{@"action":@"refresh"} reply:^(NSDictionary *replyInfo, NSError *error) {
        if (error) {
            [self showErrorMessage:error.description];
        } else {
            NSString *problem = replyInfo[@"problem"];
            if (problem) {
                [self showErrorMessage:problem];
            } else {
                [self showErrorMessage:nil];
                if (enable) {
                    [self setSwitchesEnabled:YES];
                }
                NSUInteger tube = [replyInfo[@"tube"] unsignedIntegerValue];
                NSUInteger round = [replyInfo[@"round"] unsignedIntegerValue];
                NSUInteger corner = [replyInfo[@"corner"] unsignedIntegerValue];
                if (tube != undefined) {
                    [self.tubeSwitch setOn:tube];
                    self.tube = tube;
                }
                if (round != undefined) {
                    [self.roundSwitch setOn:round];
                    self.round = round;
                }
                if (corner != undefined) {
                    [self.cornerSwitch setOn:corner];
                    self.corner = corner;
                }
                BOOL any = self.tube || self.round || self.corner == yes;
                BOOL all = self.tube && self.round && self.corner;
                [self.allOffSwitch setEnabled:any];
                [self.allOffSwitch setAlpha:any?1:0.2];
                [self.allOnSwitch setEnabled:!all];
                [self.allOnSwitch setAlpha:all?0.2:1];
            }
        }
    }];
}

- (void)awakeWithContext:(id)context {
    [super awakeWithContext:context];
    NSLog(@"awake with context %@",context);
    [self refreshSwitchesEnable:YES];
    self.awoke = YES;
}
- (void)willActivate {
    NSLog(@"activated...");
    if (self.awoke) {
        self.awoke = NO; // prevent double hit on the service at startup
    } else {
        [self refreshSwitchesEnable:NO];
    }
    [super willActivate];
}
- (void)didDeactivate {
    NSLog(@"deactivated");
    [super didDeactivate];
}
- (IBAction)tubeSwitchChanged:(BOOL)value {
    [WKInterfaceController openParentApplication:@{@"action":@"set",@"lamp":@"tube",@"value":@(value)} reply:nil];
}
- (IBAction)roundSwitchChanged:(BOOL)value {
    [WKInterfaceController openParentApplication:@{@"action":@"set",@"lamp":@"round",@"value":@(value)} reply:nil];
}
- (IBAction)cornerSwitchChanged:(BOOL)value {
    [WKInterfaceController openParentApplication:@{@"action":@"set",@"lamp":@"corner",@"value":@(value)} reply:nil];
}
- (IBAction)allOffPressed {
    [WKInterfaceController openParentApplication:@{@"action":@"allOff"} reply:^(NSDictionary *replyInfo, NSError *error) {
        [self refreshSwitchesEnable:NO];
    }];
}
- (IBAction)allOnPressed {
    [WKInterfaceController openParentApplication:@{@"action":@"allOn"} reply:^(NSDictionary *replyInfo, NSError *error) {
       [self refreshSwitchesEnable:NO];
    }];
}

@end