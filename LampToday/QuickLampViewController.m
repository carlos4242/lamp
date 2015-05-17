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

@interface QuickLampViewController () <NCWidgetProviding>

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

@implementation QuickLampViewController

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
-(void)setControlsVisible:(BOOL)controlsVisible {
    [self setControlsVisible:controlsVisible withTransitionCoordinator:nil];
}
-(void)setControlsVisible:(BOOL)visible
 withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    _controlsVisible = visible;
    BOOL onwifi = [LampService onWifi];
    void (^animations)() = ^{
        self.tubeLampLabel.alpha = visible;
        self.roundLampLabel.alpha = visible;
        self.cornerLampLabel.alpha = visible;
        self.sirenLabel.alpha = visible;
        self.tubeLampSwitch.alpha = visible;
        self.roundLampSwitch.alpha = visible;
        self.cornerLampSwitch.alpha = visible;
        self.sirenSwitch.alpha = visible;
        self.arduinoNotContactable.alpha = !visible && onwifi;
        self.turnOnWifiLabel.alpha = !visible && !onwifi;
    };
    
    if (coordinator) {
        [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
            animations();
        } completion:nil];
    } else {
        animations();
    }
    self.preferredContentSize = CGSizeMake(self.view.frame.size.width,visible?200:100);
}
-(void)setSwitchesEnabled {
    self.roundLampSwitch.on = self.lastResultLamp1On;
    self.tubeLampSwitch.on = self.lastResultLamp2On;
    self.cornerLampSwitch.on = self.lastResultLamp3On;
    self.sirenSwitch.on = self.lastResultSirenOn;
}
-(void)updateSwitchesEnabled:(LampService*)service {
    if (service) {
        self.lastResultLamp1On = [service lampOneIsOn];
        self.lastResultLamp2On = [service lampTwoIsOn];
        self.lastResultLamp3On = [service lampThreeIsOn];
        self.lastResultSirenOn = [service beedoBeedoIsOn];
        [self setSwitchesEnabled];
    }
}
-(void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    if (!CGSizeEqualToSize(self.view.frame.size,size) && coordinator) {
        [self setControlsVisible:_controlsVisible withTransitionCoordinator:coordinator];
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
        if ([LampService onHomeNetwork]) {
            self.controlsVisible = YES;
            weakSelf.preferredContentSize = CGSizeMake(self.view.frame.size.width,200);
        } else {
            self.controlsVisible = NO;
            weakSelf.preferredContentSize = CGSizeMake(self.view.frame.size.width,100);
        }
        if (result) {
            [weakSelf updateSwitchesEnabled:weakSelf.currentLampService];
            [weakSelf saveLastResults];
            if (completionHandler) {
                completionHandler(NCUpdateResultNewData);
            }
        } else {
            if (completionHandler) {
                completionHandler(NCUpdateResultNewData);
            }
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