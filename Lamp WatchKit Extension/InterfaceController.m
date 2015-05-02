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

@end


@implementation InterfaceController

- (void)awakeWithContext:(id)context {
    [super awakeWithContext:context];
    [WKInterfaceController openParentApplication:@{@"action":@"refresh"} reply:^(NSDictionary *replyInfo, NSError *error) {
        [self.tubeSwitch setEnabled:YES];
        [self.roundSwitch setEnabled:YES];
        [self.cornerSwitch setEnabled:YES];
        [self.bedoSwitch setEnabled:YES];
        [self.tubeSwitch setOn:[replyInfo[@"tube"] boolValue]];
        [self.roundSwitch setOn:[replyInfo[@"round"] boolValue]];
        [self.cornerSwitch setOn:[replyInfo[@"corner"] boolValue]];
        [self.bedoSwitch setOn:[replyInfo[@"bedo"] boolValue]];
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