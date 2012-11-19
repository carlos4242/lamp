//
//  ServiceDelegate.h
//  Friend Finder
//
//  Created by carl peto on 03/08/2010.
//  Copyright 2010 Petosoft. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ServiceBase;

@protocol ServiceDelegate <NSObject>

-(void)serviceHasFinishedWithResult:(BOOL)result forService:(ServiceBase*)service;

@optional

-(BOOL)httpErrorOccurred:(NSString*)localizedErrorDescription forService:(ServiceBase*)service;
-(BOOL)errorsOccurred:(NSArray*)errors forService:(ServiceBase*)service;
-(BOOL)warningsOccured:(NSArray*)warnings forService:(ServiceBase*)service;
-(BOOL)responseHeaderReceivedWithStatusCode:(int)statusCode forService:(ServiceBase*)service;
-(BOOL)reportError:(NSString*)error forService:(ServiceBase*)service;

@end