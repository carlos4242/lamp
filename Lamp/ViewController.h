//
//  ViewController.h
//  Lamp
//
//  Created by Carl Peto on 19/11/2012.
//  Copyright (c) 2012 Carl Peto. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController

- (IBAction)tubeLampOff:(id)sender;
- (IBAction)tubeLampOn:(id)sender;
- (IBAction)roundLampOff:(id)sender;
- (IBAction)roundLampOn:(id)sender;

@property (strong, nonatomic) IBOutlet UIButton *tubeLampOn;
@property (strong, nonatomic) IBOutlet UIButton *tubeLampOff;
@property (strong, nonatomic) IBOutlet UIButton *roundLampOn;
@property (strong, nonatomic) IBOutlet UIButton *roundLampOff;

@end
