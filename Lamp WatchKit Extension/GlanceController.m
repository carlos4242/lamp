//
//  GlanceController.m
//  Lamp WatchKit Extension
//
//  Created by Carl Peto on 19/03/2015.
//  Copyright (c) 2015 Carl Peto. All rights reserved.
//

#import "GlanceController.h"


@interface GlanceController()
@property (weak, nonatomic) IBOutlet WKInterfaceLabel *mainStatus;
@property (weak, nonatomic) IBOutlet WKInterfaceLabel *detailedStatus;

@end


@implementation GlanceController

- (void)awakeWithContext:(id)context {
    [super awakeWithContext:context];

    [WKInterfaceController openParentApplication:@{@"action":@"refresh"} reply:^(NSDictionary *replyInfo, NSError *error) {
        BOOL tubeOn = [replyInfo[@"tube"] boolValue];
        BOOL roundOn = [replyInfo[@"round"] boolValue];
        BOOL cornerOn = [replyInfo[@"corner"] boolValue];
        BOOL bedoOn = [replyInfo[@"bedo"] boolValue];
        BOOL anyOn = tubeOn||roundOn||cornerOn||bedoOn;
        [self.mainStatus setAlpha:1];
        [self.detailedStatus setAlpha:1];
        [self.mainStatus setText:anyOn?@"ON":@"OFF"];
        if (!anyOn) {
            [self.detailedStatus setText:@"All lamps are off"];
        } else {
            int lampCount = tubeOn+roundOn+cornerOn+bedoOn;
            NSMutableString *lampsOn = [@"" mutableCopy];
            if (tubeOn) {
                [lampsOn appendString:@"tube,"];
            }
            if (roundOn) {
                [lampsOn appendString:@"round,"];
            }
            if (cornerOn) {
                [lampsOn appendString:@"corner,"];
            }
            if (bedoOn) {
                [lampsOn appendString:@"flasher,"];
            }
            NSString *desc = [NSString stringWithFormat:@"\r\n%@ lamp%@ turned on",[lampsOn substringToIndex:lampsOn.length-1],lampCount>1?@"s are":@" is"];
            [self.detailedStatus setText:desc];
        }
    }];
    // Configure interface objects here.
}

- (void)willActivate {
    // This method is called when watch view controller is about to be visible to user
    [super willActivate];
}

- (void)didDeactivate {
    // This method is called when watch view controller is no longer visible
    [super didDeactivate];
}

@end