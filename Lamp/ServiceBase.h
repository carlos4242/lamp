//
//  ServiceBase.h
//  Friend Finder
//
//  Created by carl peto on 29/07/2010.
//  Copyright 2010 Petosoft. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ServiceDelegate.h"

struct timeval lastSuccessfulNetworkCall;

@class UserDetails;

@interface NSString (MD5)
-(NSString*)md5hash;
@end

@interface ServiceBase : NSObject {
	NSString *username;
	NSString *password;
	NSString *serviceCallName;
	NSString *serviceOutput;
	NSString *outputEncoding;
	long long expectedContentLength;
	int lastStatusCode;
	
	BOOL forceSynchronous;
    BOOL parallelised;
	
	NSArray *errors;
	NSArray *warnings;
	
	NSURLConnection *connection;
		
	BOOL inProgress;
	BOOL complete;
	BOOL succeededHTTP;
	BOOL serviceCallResult;
	BOOL authFailed;
	
	id<ServiceDelegate> delegate;
	
	BOOL dataReceived; //debug variable
	uint serviceCallId; //debug variable
	
	// returning YES means error was handled, do no further action (don't report in UI alert)
	BOOL (^completionFunction) (BOOL result, NSString *error);
}

//-(id)initWithUserDetails:(UserDetails*)userDetails;
-(id)initWithUsername:(NSString*)usn andPassword:(NSString*)pwd;
-(id)initWithUsername:(NSString*)usn andPassword:(NSString*)pwd isAdmin:(BOOL)isAdmin;
-(BOOL)callService:(NSString*)service;
-(void)cancel;
-(void)serviceCompletedSuccessfully;

@property (nonatomic,copy) NSString *username;
@property (nonatomic,copy) NSString *password;
@property (nonatomic,retain) id<ServiceDelegate> delegate;
@property (nonatomic,readonly) NSArray *errors;
@property (nonatomic,readonly) NSArray *warnings;
@property (nonatomic,readonly) int lastStatusCode;
@property (nonatomic) BOOL forceSynchronous;
@property (nonatomic) BOOL parallelised;

@property (copy) BOOL (^completionFunction) (BOOL result, NSString *error);

@end