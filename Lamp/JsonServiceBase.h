//
//  JsonServiceBase.h
//  Friend Finder
//
//  Created by Carl Peto on 11/04/2012.
//  Copyright (c) 2012 Petosoft. All rights reserved.
//

#import "ServiceBase.h"

@interface JsonServiceBase : ServiceBase {
}

@property (retain,readonly) NSDictionary *output;

@end