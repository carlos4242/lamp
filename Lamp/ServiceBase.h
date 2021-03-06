//
//  ServiceBase.h
//  Friend Finder
//
//  Created by carl peto on 29/07/2010.
//  Copyright 2010 Petosoft. All rights reserved.
//

#import <Foundation/Foundation.h>

struct timeval lastSuccessfulNetworkCall;

@class UserDetails;

@interface NSString (MD5)
-(NSString*)md5hash;
@end

@interface ServiceBase : NSObject {
	NSString *serviceCallName;
	NSString *serviceOutput;
	NSString *outputEncoding;
	long long expectedContentLength;
	NSURLConnection *connection;
	BOOL inProgress;
	BOOL complete;
	BOOL succeededHTTP;
	BOOL serviceCallResult;
	BOOL authFailed;
	BOOL dataReceived; //debug variable
	uint serviceCallId; //debug variable
}

-(BOOL)callService:(NSString*)service postData:(NSString*)postData;
-(void)cancel;
-(void)serviceCompletedSuccessfully;

@property (nonatomic,copy) NSString *username;
@property (nonatomic,copy) NSString *password;
@property (nonatomic) NSArray *errors;
@property (nonatomic) NSArray *warnings;
@property (nonatomic,readonly) NSInteger lastStatusCode;
@property (nonatomic) BOOL forceSynchronous;
@property (nonatomic) BOOL parallelised;
@property (copy) BOOL (^completionFunction) (BOOL result, NSString *error);

@end