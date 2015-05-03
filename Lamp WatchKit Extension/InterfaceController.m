//
//  InterfaceController.m
//  Lamp WatchKit Extension
//
//  Created by Carl Peto on 19/03/2015.
//  Copyright (c) 2015 Carl Peto. All rights reserved.
//

#import "InterfaceController.h"


@interface InterfaceController()
@property (weak, nonatomic) IBOutlet WKInterfaceSwitch *tubeSwitch;
@property (weak, nonatomic) IBOutlet WKInterfaceSwitch *roundSwitch;
@property (weak, nonatomic) IBOutlet WKInterfaceSwitch *cornerSwitch;
@property (weak, nonatomic) IBOutlet WKInterfaceSwitch *bedoSwitch;
@property (weak, nonatomic) IBOutlet WKInterfaceLabel *errorLabel;

@end


@implementation InterfaceController

-(void)setSwitchesEnabled:(BOOL)enabled {
    [self.tubeSwitch setEnabled:enabled];
    [self.roundSwitch setEnabled:enabled];
    [self.cornerSwitch setEnabled:enabled];
    [self.bedoSwitch setEnabled:enabled];
    [self.tubeSwitch setAlpha:enabled?1:0.2];
    [self.roundSwitch setAlpha:enabled?1:0.2];
    [self.cornerSwitch setAlpha:enabled?1:0.2];
    [self.bedoSwitch setAlpha:enabled?1:0.2];
}

-(void)setSwitchesHidden:(BOOL)hidden {
    [self.tubeSwitch setHidden:hidden];
    [self.roundSwitch setHidden:hidden];
    [self.cornerSwitch setHidden:hidden];
    [self.bedoSwitch setHidden:hidden];
}

-(void)showErrorMessage:(NSString*)message {
    [self setSwitchesHidden:YES];
    [self.errorLabel setHidden:NO];
    [self.errorLabel setText:message];
}

- (void)awakeWithContext:(id)context {
    [super awakeWithContext:context];
    [WKInterfaceController openParentApplication:@{@"action":@"refresh"} reply:^(NSDictionary *replyInfo, NSError *error) {
        if (error) {
            [self showErrorMessage:error.description];
        } else {
            [self setSwitchesEnabled:YES];
            [self.tubeSwitch setOn:[replyInfo[@"tube"] boolValue]];
            [self.roundSwitch setOn:[replyInfo[@"round"] boolValue]];
            [self.cornerSwitch setOn:[replyInfo[@"corner"] boolValue]];
            [self.bedoSwitch setOn:[replyInfo[@"bedo"] boolValue]];
        }
    }];
}
- (void)willActivate {
    [super willActivate];
}
- (void)didDeactivate {
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
- (IBAction)bedoSwitchChanged:(BOOL)value {
    [WKInterfaceController openParentApplication:@{@"action":@"set",@"lamp":@"bedo",@"value":@(value)} reply:nil];
}

@end