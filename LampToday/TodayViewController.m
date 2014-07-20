//
//  TodayViewController.m
//  LampToday
//
//  Created by Carl Peto on 20/07/2014.
//  Copyright (c) 2014 Carl Peto. All rights reserved.
//

#import "TodayViewController.h"
#import "LampService.h"

#import <NotificationCenter/NotificationCenter.h>

@interface TodayViewController () <NCWidgetProviding>

@property (weak, nonatomic) IBOutlet UISwitch *tubeLampSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *roundLampSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *cornerLampSwitch;

@end

@implementation TodayViewController

+(void)initialize {
    NSLog(@"TodayViewController class initialised");
}

-(void)viewDidLoad {
    self.preferredContentSize = CGSizeMake(self.view.frame.size.width,100.0);
    LampService *lamp = [self lampService:nil];
    [lamp checkState];
    NSLog(@"widget view loaded");
}

-(void)updateSwitchVisibility:(BOOL)visible {
    CGFloat alpha = visible?1.0:0.2;
    self.tubeLampSwitch.alpha = alpha;
    self.roundLampSwitch.alpha = alpha;
    self.cornerLampSwitch.alpha = alpha;
}

-(void)updateSwitchesEnabled:(LampService*)service {
    self.roundLampSwitch.on = [service lampOneIsOn];
    self.tubeLampSwitch.on = [service lampTwoIsOn];
    self.cornerLampSwitch.on = [service lampThreeIsOn];
}

- (void)widgetPerformUpdateWithCompletionHandler:(void (^)(NCUpdateResult))completionHandler {
    LampService *lamp = [self lampService:completionHandler];
    [lamp checkState];
    NSLog(@"widget snapshot");
}
-(LampService*)lampService:(void (^)(NCUpdateResult))completionHandler {
    LampService *lamp = [LampService new];
    __weak LampService *ls = lamp;
    lamp.completionFunction = ^(BOOL result,NSString *error) {
        NSLog(@"widget webservice completed with result %d",result);
        [self updateSwitchVisibility:result];
        if (result) {
            [self updateSwitchesEnabled:ls];
        }
        if (completionHandler) {
            NSLog(@"widget snapshot callback");
            completionHandler(result?NCUpdateResultNewData:NCUpdateResultFailed);
        }
        return YES;
    };
    return lamp;
}
- (IBAction)roundLampSwitched:(id)sender {
    [[self lampService:nil] lampOneSetState:self.roundLampSwitch.on];
}
- (IBAction)tubeLampSwitched:(id)sender {
    [[self lampService:nil] lampTwoSetState:self.tubeLampSwitch.on];
}
- (IBAction)cornerLampSwitched:(id)sender {
    [[self lampService:nil] lampThreeSetState:self.cornerLampSwitch.on];
}

@end