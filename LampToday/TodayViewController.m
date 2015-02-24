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
#define kLastResultSirenOn @"kLastResultSirenOn"

@interface TodayViewController () <NCWidgetProviding>

@property (strong, nonatomic) IBOutlet UIVisualEffectView *visualEffectView;
@property (weak, nonatomic) IBOutlet UISwitch *tubeLampSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *roundLampSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *cornerLampSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *sirenSwitch;
@property (weak, nonatomic) IBOutlet UILabel *tubeLampLabel;
@property (weak, nonatomic) IBOutlet UILabel *roundLampLabel;
@property (weak, nonatomic) IBOutlet UILabel *cornerLampLabel;
@property (weak, nonatomic) IBOutlet UILabel *arduinoNotContactable;
@property (weak, nonatomic) IBOutlet UILabel *sirenLabel;
@property (weak, nonatomic) IBOutlet UILabel *turnOnWifiLabel;

@property (nonatomic) BOOL controlsVisible;
@property BOOL lastResultLamp1On;
@property BOOL lastResultLamp2On;
@property BOOL lastResultLamp3On;
@property BOOL lastResultSirenOn;

@property (strong) LampService *currentLampService;

@end

@implementation TodayViewController

-(void)viewDidLoad {
    self.visualEffectView = [[UIVisualEffectView alloc] initWithEffect:[UIVibrancyEffect notificationCenterVibrancyEffect]];
    self.visualEffectView.frame = CGRectMake(0, 0, self.view.frame.size.width, 200);
    [self.view addSubview:self.visualEffectView];
    NSLog(@"visual effect view %@",self.visualEffectView);

    [self.visualEffectView.contentView addSubview:self.roundLampLabel];
    [self.visualEffectView.contentView addSubview:self.tubeLampLabel];
    [self.visualEffectView.contentView addSubview:self.cornerLampLabel];
    [self.visualEffectView.contentView addSubview:self.sirenLabel];
    [self.visualEffectView.contentView addSubview:self.roundLampSwitch];
    [self.visualEffectView.contentView addSubview:self.tubeLampSwitch];
    [self.visualEffectView.contentView addSubview:self.cornerLampSwitch];
    [self.visualEffectView.contentView addSubview:self.sirenSwitch];
    [self.visualEffectView.contentView addSubview:self.arduinoNotContactable];
    [self.visualEffectView.contentView addSubview:self.turnOnWifiLabel];
    
    [self loadLastResults];
    [self setSwitchesEnabled];
    
    LampService *lamp = [self lampService:nil];
    BOOL ran = [lamp checkState];
    NSLog(@"widget view did load %d",ran);
}
-(void)setControlsVisible:(BOOL)visible {
    _controlsVisible = visible;
    self.tubeLampLabel.hidden = !visible;
    self.roundLampLabel.hidden = !visible;
    self.cornerLampLabel.hidden = !visible;
    self.sirenLabel.hidden = !visible;
    self.tubeLampSwitch.hidden = !visible;
    self.roundLampSwitch.hidden = !visible;
    self.cornerLampSwitch.hidden = !visible;
    self.sirenSwitch.hidden = !visible;
    self.arduinoNotContactable.hidden = visible;
    self.turnOnWifiLabel.hidden = visible;
    if (visible) {
        self.preferredContentSize = CGSizeMake(self.view.frame.size.width,200);
        NSLog(@"set preferred content size height to 200");
    } else {
        self.preferredContentSize = CGSizeMake(self.view.frame.size.width,100);
        NSLog(@"set preferred content size height to 100");
    }
}
-(void)setSwitchesEnabled {
    self.roundLampSwitch.on = self.lastResultLamp1On;
    self.tubeLampSwitch.on = self.lastResultLamp2On;
    self.cornerLampSwitch.on = self.lastResultLamp3On;
    self.sirenSwitch.on = self.lastResultSirenOn;
}
-(void)updateSwitchesEnabled:(LampService*)service {
    self.lastResultLamp1On = [service lampOneIsOn];
    self.lastResultLamp2On = [service lampTwoIsOn];
    self.lastResultLamp3On = [service lampThreeIsOn];
    self.lastResultSirenOn = [service beedoBeedoIsOn];
    [self setSwitchesEnabled];
}
- (void)widgetPerformUpdateWithCompletionHandler:(void (^)(NCUpdateResult))completionHandler {
    LampService *lamp = [self lampService:completionHandler];
    BOOL ran = [lamp checkState];
    NSLog(@"widget snapshot %d",ran);
}
-(LampService*)lampService:(void (^)(NCUpdateResult))completionHandler {
    LampService *lamp = [LampService new];
    self.currentLampService = lamp;
    __weak LampService *ls = lamp;
    lamp.completionFunction = ^(BOOL result,NSString *error) {
        self.controlsVisible = result;
        NSLog(@"widget webservice completed with result %d",result);
        if (result) {
            [self updateSwitchesEnabled:ls];
        }
        [self saveLastResults];
        if (completionHandler) {
            NSLog(@"widget snapshot callback");
            completionHandler(NCUpdateResultNewData);
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
- (IBAction)sirenSwitched:(id)sender {
    [[self lampService:nil] beedoBeedoSetState:self.sirenSwitch.on];
}
-(void)saveLastResults {
    [[NSUserDefaults standardUserDefaults] setBool:self.controlsVisible forKey:kLastResultVisible];
    [[NSUserDefaults standardUserDefaults] setBool:self.lastResultLamp1On forKey:kLastResultLamp1On];
    [[NSUserDefaults standardUserDefaults] setBool:self.lastResultLamp2On forKey:kLastResultLamp2On];
    [[NSUserDefaults standardUserDefaults] setBool:self.lastResultLamp3On forKey:kLastResultLamp3On];
    [[NSUserDefaults standardUserDefaults] setBool:self.lastResultSirenOn forKey:kLastResultSirenOn];
}
-(void)loadLastResults {
    self.controlsVisible = [[NSUserDefaults standardUserDefaults] boolForKey:kLastResultVisible];
    self.lastResultLamp1On = [[NSUserDefaults standardUserDefaults] boolForKey:kLastResultLamp1On];
    self.lastResultLamp2On = [[NSUserDefaults standardUserDefaults] boolForKey:kLastResultLamp2On];
    self.lastResultLamp3On = [[NSUserDefaults standardUserDefaults] boolForKey:kLastResultLamp3On];
    self.lastResultSirenOn = [[NSUserDefaults standardUserDefaults] boolForKey:kLastResultSirenOn];
}

@end