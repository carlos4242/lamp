//
//  LampService.h
//  Lamp
//
//  Created by Carl Peto on 19/11/2012.
//  Copyright (c) 2012 Carl Peto. All rights reserved.
//

#import "ServiceBase.h"

@interface LampService : ServiceBase {
    BOOL lampOnOff;
}

-(void)setLampOnOff:(BOOL)onOff;

@end
