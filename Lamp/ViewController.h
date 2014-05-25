//
//  ViewController.h
//  Lamp
//
//  Created by Carl Peto on 19/11/2012.
//  Copyright (c) 2012 Carl Peto. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController

@property (weak, nonatomic) IBOutlet UIButton *tubeLampOnButton;
@property (weak, nonatomic) IBOutlet UIButton *tubeLampOffButton;
@property (weak, nonatomic) IBOutlet UIButton *roundLampOnButton;
@property (weak, nonatomic) IBOutlet UIButton *roundLampOffButton;
@property (weak, nonatomic) IBOutlet UIButton *cornerLampOnButton;
@property (weak, nonatomic) IBOutlet UIButton *cornerLampOffButton;

@end