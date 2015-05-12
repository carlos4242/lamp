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

@property (weak, nonatomic) IBOutlet WKInterfaceButton *allOffSwitch;
@property (weak, nonatomic) IBOutlet WKInterfaceButton *allOnSwitch;

@property BOOL awoke;

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

-(void)refreshSwitchesEnable:(BOOL)enable {
    [WKInterfaceController openParentApplication:@{@"action":@"refresh"} reply:^(NSDictionary *replyInfo, NSError *error) {
        if (error) {
            [self showErrorMessage:error.description];
        } else {
            if (enable) {
                [self setSwitchesEnabled:YES];
            }
            BOOL tube = [replyInfo[@"tube"] boolValue];
            BOOL round = [replyInfo[@"round"] boolValue];
            BOOL corner = [replyInfo[@"corner"] boolValue];
            BOOL siren = [replyInfo[@"bedo"] boolValue];
            BOOL any = tube|round|corner|siren;
            BOOL all = tube&round&corner;
            [self.tubeSwitch setOn:tube];
            [self.roundSwitch setOn:round];
            [self.cornerSwitch setOn:corner];
            [self.bedoSwitch setOn:siren];
            [self.allOffSwitch setEnabled:any];
            [self.allOffSwitch setAlpha:any?1:0.2];
            [self.allOnSwitch setEnabled:!all];
            [self.allOnSwitch setAlpha:all?0.2:1];
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
- (IBAction)bedoSwitchChanged:(BOOL)value {
    [WKInterfaceController openParentApplication:@{@"action":@"set",@"lamp":@"bedo",@"value":@(value)} reply:nil];
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