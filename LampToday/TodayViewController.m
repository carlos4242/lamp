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

#define kLastResultVisible @"kLastResultVisible"
#define kLastResultLamp1On @"kLastResultLamp1On"
#define kLastResultLamp2On @"kLastResultLamp2On"
#define kLastResultLamp3On @"kLastResultLamp3On"

@interface TodayViewController () <NCWidgetProviding>

@property (weak, nonatomic) IBOutlet UISwitch *tubeLampSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *roundLampSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *cornerLampSwitch;
@property (weak, nonatomic) IBOutlet UILabel *tubeLampLabel;
@property (weak, nonatomic) IBOutlet UILabel *roundLampLabel;
@property (weak, nonatomic) IBOutlet UILabel *cornerLampLabel;

@property BOOL lastResultVisible;
@property BOOL lastResultLamp1On;
@property BOOL lastResultLamp2On;
@property BOOL lastResultLamp3On;

@end

@implementation TodayViewController

-(void)viewDidLoad {
    [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(heartbeat) userInfo:nil repeats:YES];
    self.preferredContentSize = CGSizeMake(self.view.frame.size.width,150.0);
    [self loadLastResults];
    [self updateSwitchVisibility:self.lastResultVisible];
    [self setSwitchesEnabled];
    
    LampService *lamp = [self lampService:nil];
    BOOL ran = [lamp checkState];
    NSLog(@"widget view did load %d",ran);
}
-(void)heartbeat {
    NSLog(@"heartbeat");
}
-(void)updateSwitchVisibility:(BOOL)visible {
    self.tubeLampLabel.textColor = visible?[UIColor whiteColor]:[UIColor redColor];
    self.roundLampLabel.textColor = visible?[UIColor whiteColor]:[UIColor redColor];
    self.cornerLampLabel.textColor = visible?[UIColor whiteColor]:[UIColor redColor];
    
    self.tubeLampSwitch.hidden = !visible;
    self.roundLampSwitch.alpha = !visible;
    self.cornerLampSwitch.alpha = !visible;
}
-(void)setSwitchesEnabled {
    self.roundLampSwitch.on = self.lastResultLamp1On;
    self.tubeLampSwitch.on = self.lastResultLamp2On;
    self.cornerLampSwitch.on = self.lastResultLamp3On;
}
-(void)updateSwitchesEnabled:(LampService*)service {
    self.lastResultLamp1On = [service lampOneIsOn];
    self.lastResultLamp2On = [service lampTwoIsOn];
    self.lastResultLamp3On = [service lampThreeIsOn];
    [self setSwitchesEnabled];
}
- (void)widgetPerformUpdateWithCompletionHandler:(void (^)(NCUpdateResult))completionHandler {
    LampService *lamp = [self lampService:completionHandler];
    BOOL ran = [lamp checkState];
    NSLog(@"widget snapshot %d",ran);
}
-(LampService*)lampService:(void (^)(NCUpdateResult))completionHandler {
    LampService *lamp = [LampService new];
    __weak LampService *ls = lamp;
    lamp.completionFunction = ^(BOOL result,NSString *error) {
        self.lastResultVisible = result;
        NSLog(@"widget webservice completed with result %d",result);
        [self updateSwitchVisibility:result];
        if (result) {
            [self updateSwitchesEnabled:ls];
        }
        [self saveLastResults];
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

-(void)saveLastResults {
    [[NSUserDefaults standardUserDefaults] setBool:self.lastResultVisible forKey:kLastResultVisible];
    [[NSUserDefaults standardUserDefaults] setBool:self.lastResultLamp1On forKey:kLastResultLamp1On];
    [[NSUserDefaults standardUserDefaults] setBool:self.lastResultLamp2On forKey:kLastResultLamp2On];
    [[NSUserDefaults standardUserDefaults] setBool:self.lastResultLamp3On forKey:kLastResultLamp3On];
}
-(void)loadLastResults {
    self.lastResultVisible = [[NSUserDefaults standardUserDefaults] boolForKey:kLastResultVisible];
    self.lastResultLamp1On = [[NSUserDefaults standardUserDefaults] boolForKey:kLastResultLamp1On];
    self.lastResultLamp2On = [[NSUserDefaults standardUserDefaults] boolForKey:kLastResultLamp2On];
    self.lastResultLamp3On = [[NSUserDefaults standardUserDefaults] boolForKey:kLastResultLamp3On];
}

@end