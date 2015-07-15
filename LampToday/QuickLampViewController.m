//
//  TodayViewController.m
//  LampToday
//
//  Created by Carl Peto on 20/07/2014.
//  Copyright (c) 2014 Carl Peto. All rights reserved.
//

#import "QuickLampViewController.h"
#import "LampService.h"

#import <NotificationCenter/NotificationCenter.h>

#define kLastResultVisible @"kLastResultVisible"
#define kLastResultLamp1On @"kLastResultLamp1On"
#define kLastResultLamp2On @"kLastResultLamp2On"
#define kLastResultLamp3On @"kLastResultLamp3On"
#define kLastResultSirenOn @"kLastResultSirenOn"
#define kLastResultAnyOn @"kLastResultAnyOn"
#define kLastResultNotAllOn @"kLastResultNotAllOn"

@interface QuickLampViewController () <NCWidgetProviding>

@property (strong, nonatomic) IBOutlet UIVisualEffectView *visualEffectView;
@property (weak, nonatomic) IBOutlet UISwitch *tubeLampSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *roundLampSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *cornerLampSwitch;
@property (weak, nonatomic) IBOutlet UILabel *tubeLampLabel;
@property (weak, nonatomic) IBOutlet UILabel *roundLampLabel;
@property (weak, nonatomic) IBOutlet UILabel *cornerLampLabel;
@property (weak, nonatomic) IBOutlet UILabel *arduinoNotContactable;
@property (weak, nonatomic) IBOutlet UILabel *turnOnWifiLabel;
@property (weak, nonatomic) IBOutlet UIButton *allOffButton;
@property (weak, nonatomic) IBOutlet UIButton *allOnButton;

@property (nonatomic) BOOL controlsVisible;
@property BOOL lastResultLamp1On;
@property BOOL lastResultLamp2On;
@property BOOL lastResultLamp3On;
@property BOOL lastResultAnyOn;
@property BOOL lastResultNotAllOn;

@property (strong) LampService *currentLampService;

@end

@implementation QuickLampViewController

-(void)viewDidLoad {
    self.visualEffectView = [[UIVisualEffectView alloc] initWithEffect:[UIVibrancyEffect notificationCenterVibrancyEffect]];
    self.visualEffectView.frame = CGRectMake(0, 0, self.view.frame.size.width, 250);
    self.preferredContentSize = CGSizeMake(self.view.frame.size.width,250);
    [self.view addSubview:self.visualEffectView];
    [self.visualEffectView.contentView addSubview:self.roundLampLabel];
    [self.visualEffectView.contentView addSubview:self.tubeLampLabel];
    [self.visualEffectView.contentView addSubview:self.cornerLampLabel];
    [self.visualEffectView.contentView addSubview:self.roundLampSwitch];
    [self.visualEffectView.contentView addSubview:self.tubeLampSwitch];
    [self.visualEffectView.contentView addSubview:self.cornerLampSwitch];
    [self.visualEffectView.contentView addSubview:self.arduinoNotContactable];
    [self.visualEffectView.contentView addSubview:self.turnOnWifiLabel];
    [self.visualEffectView.contentView addSubview:self.allOffButton];
    [self.visualEffectView.contentView addSubview:self.allOnButton];
    self.allOffButton.layer.borderColor = [UIColor whiteColor].CGColor;
    self.allOffButton.layer.borderWidth = 0.5;
    self.allOffButton.layer.cornerRadius = 3;
    self.allOnButton.layer.borderColor = [UIColor whiteColor].CGColor;
    self.allOnButton.layer.borderWidth = 0.5;
    self.allOnButton.layer.cornerRadius = 3;
    
    [self loadLastResults];
    [self setSwitchesEnabled];
    
    LampService *lamp = [self lampService:nil];
    [lamp checkState];
}
-(void)setControlsVisible:(BOOL)visible {
    _controlsVisible = visible;
    BOOL onwifi = [LampService onWifi];
    void (^animations)() = ^{
        self.tubeLampLabel.hidden = !visible;
        self.roundLampLabel.hidden = !visible;
        self.cornerLampLabel.hidden = !visible;
        self.tubeLampSwitch.hidden = !visible;
        self.roundLampSwitch.hidden = !visible;
        self.cornerLampSwitch.hidden = !visible;
        self.allOnButton.hidden = !visible;
        self.allOffButton.hidden = !visible;
        self.arduinoNotContactable.hidden = visible || !onwifi;
        self.turnOnWifiLabel.hidden = visible || onwifi;
    };
    
    [UIView animateWithDuration:0.2 animations:animations];
}
-(void)setSwitchesEnabled {
    self.roundLampSwitch.on = self.lastResultLamp1On;
    self.tubeLampSwitch.on = self.lastResultLamp2On;
    self.cornerLampSwitch.on = self.lastResultLamp3On;
    self.allOffButton.enabled = self.lastResultAnyOn;
    self.allOffButton.alpha = self.allOffButton.enabled?1:0.2;
    self.allOnButton.enabled = self.lastResultNotAllOn;
    self.allOnButton.alpha = self.allOnButton.enabled?1:0.2;
}
-(void)updateSwitchesEnabled:(LampService*)service {
    if (service) {
        self.lastResultLamp1On = [service lampOneIsOn];
        self.lastResultLamp2On = [service lampTwoIsOn];
        self.lastResultLamp3On = [service lampThreeIsOn];
        BOOL anyOn = [service lampOneIsOn] || [service lampTwoIsOn] || [service lampThreeIsOn];
        BOOL allOn = [service lampOneIsOn] && [service lampTwoIsOn] && [service lampThreeIsOn];
        self.lastResultAnyOn = anyOn;
        self.lastResultNotAllOn = !allOn;
        [self setSwitchesEnabled];
    }
}
- (void)widgetPerformUpdateWithCompletionHandler:(void (^)(NCUpdateResult))completionHandler {
    LampService *lamp = [self lampService:completionHandler];
    [lamp checkState];
}
-(LampService*)lampService:(void (^)(NCUpdateResult))completionHandler {
    LampService *lamp = [LampService new];
    self.currentLampService = lamp;
    __weak QuickLampViewController *weakSelf = self;
    lamp.completionFunction = ^(BOOL result,NSString *error) {
        self.controlsVisible = [LampService onHomeNetwork];
        if (result) {
            [weakSelf updateSwitchesEnabled:weakSelf.currentLampService];
            [weakSelf saveLastResults];
        }
        if (completionHandler) {
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
- (IBAction)allOnClicked:(id)sender {
    [[self lampService:nil] allOn];
}
- (IBAction)allOffClicked:(id)sender {
    [[self lampService:nil] allOff];
}
-(void)saveLastResults {
    [[NSUserDefaults standardUserDefaults] setBool:self.controlsVisible forKey:kLastResultVisible];
    [[NSUserDefaults standardUserDefaults] setBool:self.lastResultLamp1On forKey:kLastResultLamp1On];
    [[NSUserDefaults standardUserDefaults] setBool:self.lastResultLamp2On forKey:kLastResultLamp2On];
    [[NSUserDefaults standardUserDefaults] setBool:self.lastResultLamp3On forKey:kLastResultLamp3On];
    [[NSUserDefaults standardUserDefaults] setBool:self.lastResultAnyOn forKey:kLastResultAnyOn];
    [[NSUserDefaults standardUserDefaults] setBool:self.lastResultNotAllOn forKey:kLastResultNotAllOn];
}
-(void)loadLastResults {
    self.controlsVisible = [[NSUserDefaults standardUserDefaults] boolForKey:kLastResultVisible];
    self.lastResultLamp1On = [[NSUserDefaults standardUserDefaults] boolForKey:kLastResultLamp1On];
    self.lastResultLamp2On = [[NSUserDefaults standardUserDefaults] boolForKey:kLastResultLamp2On];
    self.lastResultLamp3On = [[NSUserDefaults standardUserDefaults] boolForKey:kLastResultLamp3On];
    self.lastResultAnyOn = [[NSUserDefaults standardUserDefaults] boolForKey:kLastResultAnyOn];
    self.lastResultNotAllOn = [[NSUserDefaults standardUserDefaults] boolForKey:kLastResultNotAllOn];
}

@end