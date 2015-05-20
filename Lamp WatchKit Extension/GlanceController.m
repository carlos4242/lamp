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
@property BOOL awoke;

@end

@implementation GlanceController

-(void)refreshGlance:(BOOL)show {
    [WKInterfaceController openParentApplication:@{@"action":@"refresh"} reply:^(NSDictionary *replyInfo, NSError *error) {
        if (show) {
            [self.mainStatus setAlpha:1];
            [self.detailedStatus setAlpha:1];
        }
        
        if (error) {
            [self.mainStatus setText:@""];
            [self.detailedStatus setText:error.description];
        } else {
            NSString *problem = replyInfo[@"problem"];
            if (problem) {
                [self.mainStatus setText:@""];
                [self.detailedStatus setText:problem];
            } else {
                BOOL tubeOn = [replyInfo[@"tube"] boolValue];
                BOOL roundOn = [replyInfo[@"round"] boolValue];
                BOOL cornerOn = [replyInfo[@"corner"] boolValue];
                BOOL bedoOn = [replyInfo[@"bedo"] boolValue];
                BOOL anyOn = tubeOn||roundOn||cornerOn||bedoOn;
                
                
                if (anyOn) {
                    [self.mainStatus setText:@"ON"];
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
                } else {
                    [self.mainStatus setText:@"OFF"];
                    [self.detailedStatus setText:@"All lamps are off"];
                }
            }
        }

    }];
}

- (void)awakeWithContext:(id)context {
    [super awakeWithContext:context];
    [self refreshGlance:YES];
    self.awoke = YES;
}

- (void)willActivate {
    // This method is called when watch view controller is about to be visible to user
    NSLog(@"glance activated");
    if (self.awoke) {
        self.awoke = NO; // prevent double call
    } else {
        [self refreshGlance:NO];
    }
    [super willActivate];
}

- (void)didDeactivate {
    // This method is called when watch view controller is no longer visible
    NSLog(@"glance deactivated");
    [super didDeactivate];
}

@end