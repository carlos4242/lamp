//
//  ServiceBase.m
//  Friend Finder
//
//  Created by carl peto on 29/07/2010.
//  Copyright 2010 Petosoft. All rights reserved.
//

#import "ServiceBase.h"
//#import "UserDetails.h"
//#import "Friend_FinderAppDelegate.h"
#import <CommonCrypto/CommonDigest.h>
#import "NSData+Base64.h"
#include <sys/time.h>

@implementation NSString (MD5)
-(NSString*)md5hash {
	const char* str = [self UTF8String];
    unsigned char result[CC_MD5_DIGEST_LENGTH];
    CC_MD5(str, strlen(str), result);
	
    NSMutableString *ret = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH*2];
    for(int i = 0; i<CC_MD5_DIGEST_LENGTH; i++) {
        [ret appendFormat:@"%02x",result[i]];
    }
    return ret;
}
@end

@interface ServiceBase ()
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response;
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data;
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error;
@end

@implementation ServiceBase

#pragma mark - properties

@synthesize username,password,delegate,errors,warnings,lastStatusCode,forceSynchronous,completionFunction,parallelised;

#pragma mark - constructors/dealloc

//-(id)initWithUserDetails:(UserDetails*)userDetails {
//	return [self initWithUsername:userDetails.username andPassword:userDetails.password];
//}

-(id)initWithUsername:(NSString*)usn
		  andPassword:(NSString*)pwd {
	return [self initWithUsername:usn andPassword:pwd isAdmin:NO];
}

-(id)initWithUsername:(NSString*)usn
		  andPassword:(NSString*)pwd
			  isAdmin:(BOOL)isAdmin {

    self = [self init];
	if (self) {
		self.username = usn;
		self.password = pwd;
	}
	return self;
}

-(id)init {
    self = [super init];
	if (self) {
		dataReceived = NO;
		inProgress = NO;
		complete = NO;
		succeededHTTP = YES; // until we know otherwise
		serviceCallResult = NO; //until we know better
		forceSynchronous = NO;
		serviceCallId = random()%1000;
		authFailed = NO;
    }
	return self;
}

-(void)dealloc {
	[username release];
	[password release];
	[serviceCallName release];
	[(id)delegate release];
	[serviceOutput release];
	[outputEncoding release];
	[connection release];
	[errors release];
	[warnings release];
	[completionFunction release];
	[super dealloc];
	NSLog(@"(%d) finished service base dealloc",serviceCallId);
}

#pragma mark - serialised requests

static dispatch_queue_t wsQ;
+(void)initialize {
    wsQ = dispatch_queue_create("web service 1", NULL);
}

#pragma mark - template methods

-(NSString*)requestBody {
	return @"";
}

-(NSURL*)getServiceUrlFromService:(NSString*)service {
	serviceCallName = [[NSString alloc] initWithString:service];
	NSString *urlString = [NSString stringWithFormat:@"%@%@",serviceRoot,service];
	NSLog(@"(%d) Sending url %@",serviceCallId,urlString);
	return [NSURL URLWithString:urlString];
}
-(NSMutableURLRequest*)requestForService:(NSString*)service {
    NSURL *url = [self getServiceUrlFromService:service];
	NSMutableURLRequest *urlRequest = [[[NSMutableURLRequest alloc] initWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:60.0] autorelease];
    [urlRequest setHTTPShouldHandleCookies:YES];
	[urlRequest setHTTPMethod:@"POST"];
    return urlRequest;
}
-(void)setupSecurityForRequest:(NSMutableURLRequest*)urlRequest {
    NSString *tmp = [NSString stringWithFormat:@"%@:%@", username, [password md5hash]];
    NSString *basicAuthHeader = [NSString stringWithFormat:@"Basic %@",
                                 [[NSData dataWithBytes:[tmp cStringUsingEncoding:NSUTF8StringEncoding]
                                                 length:[tmp length]] base64EncodedString]];
    [urlRequest addValue:basicAuthHeader forHTTPHeaderField:@"Authorization"];
}
-(NSTimeInterval)getSynchronousTimeoutValue {
    return 5.0F;
}
-(NSTimeInterval)getSerialisedTimeoutValue {
    return 18.0F;
}
-(BOOL)callService:(NSString*)service  {
	if (!forceSynchronous&&parallelised) {
        NSMutableURLRequest *urlRequest = [self requestForService:service];
        [urlRequest setHTTPBody:[[self requestBody] dataUsingEncoding:NSASCIIStringEncoding]];
        if (![NSURLConnection canHandleRequest:urlRequest]) return NO;
        
        [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
        
		connection = [[NSURLConnection alloc] initWithRequest:urlRequest delegate:self startImmediately:NO];

		if (connection) {
            [connection start];
            inProgress = YES;
        }

		return (!connection);		
	} else {
        BOOL (^webService)() = ^{
            NSMutableURLRequest *urlRequest = [self requestForService:service];
            [urlRequest setHTTPBody:[[self requestBody] dataUsingEncoding:NSASCIIStringEncoding]];
            if (![NSURLConnection canHandleRequest:urlRequest]) return NO;
            
            [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
            
            NSURLResponse *response = nil;
            NSError *error = nil;
            if (forceSynchronous) {
                urlRequest.timeoutInterval = [self getSynchronousTimeoutValue];
            }
            NSData *data = [NSURLConnection sendSynchronousRequest:urlRequest returningResponse:&response error:&error];
            [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
            
            if (error) {
                if ([NSThread isMainThread]) {
                    [self connection:connection didFailWithError:error];
                } else {
                    dispatch_sync(dispatch_get_main_queue(), ^{
                        [self connection:connection didFailWithError:error];
                    });
                }
                return NO;
            } else if (response) {
                if ([NSThread isMainThread]) {
                    [self connection:connection didReceiveResponse:response];
                    if (data) {
                        [self connection:connection didReceiveData:data];
                    } else {
                        NSLog(@"(%d) synchronous request returned no data",serviceCallId);
                    }
                    [self connectionDidFinishLoading:connection];
                } else {
                    dispatch_sync(dispatch_get_main_queue(), ^{
                        [self connection:connection didReceiveResponse:response];
                        if (data) {
                            [self connection:connection didReceiveData:data];
                        } else {
                            NSLog(@"(%d) synchronous request returned no data",serviceCallId);
                        }
                        [self connectionDidFinishLoading:connection];
                    });
                }
                return YES;
            } else {
                NSLog(@"(%d) synchronous request returned no response",serviceCallId);
                if ([NSThread isMainThread]) {
                    [self connectionDidFinishLoading:connection];
                } else {
                    dispatch_sync(dispatch_get_main_queue(), ^{
                        [self connectionDidFinishLoading:connection];
                    });
                }
                return NO;
            }
        };
		if (forceSynchronous) {
            // run on the current (GUI/main) thread
            return webService();
        } else {
            __block BOOL (^serialisedWebService) () = [webService copy];
            // run on the background, serialised queue (standard)
            dispatch_async(wsQ, ^{
                serialisedWebService();
                [serialisedWebService release];
                serialisedWebService = nil;
            });
            return YES; // assume it was queued OK
        }
	}
}

- (void)cancel {
	if (connection) {
		[connection cancel];
		NSLog(@"(%d) cancelled",serviceCallId);
	}
	
	inProgress = NO;
}

-(void)serviceCompletedSuccessfully {
    gettimeofday(&lastSuccessfulNetworkCall,NULL);
}
-(void)handleErrorsInCompletedResult:(NSString**)lastErrorParsed {
    if ([(id)delegate respondsToSelector:@selector(errorsOccurred:forService:)]) {
        [delegate errorsOccurred:errors forService:self];
    }
}
-(void)handleWarningsInCompletedResult {
    if ([(id)delegate respondsToSelector:@selector(warningsOccured:forService:)]) {
        [delegate warningsOccured:warnings forService:self];
    } else {
        NSLog(@"unlogged warnings on service %@",warnings);
    }
}
-(void)parseSuccessfulCompletionOfService:(NSString**)lastErrorParsed {
    serviceCallResult = NO; // no answer means no
    
    if (serviceCallResult) {
		[self serviceCompletedSuccessfully]; // this is overridden in subclasses to finalise processing of the service
	}

    BOOL handled = completionFunction&&completionFunction(serviceCallResult,*lastErrorParsed);

    if (!delegate&&!handled) {
        NSLog(@"service finished with no delegate set, errors and warnings will not show");
    }
    
    if (delegate&&!handled) {
		NSLog(@"(%d) Service complete, calling the delegate with result %d",serviceCallId,serviceCallResult);
		[delegate serviceHasFinishedWithResult:serviceCallResult forService:self];
	}
}
-(void)parseErrorCompletionOfService:(NSString**)lastErrorParsed {
    NSString *error = nil;
    serviceCallResult = NO;
    
    if (lastStatusCode==500) {
        error = @"Internal server error.";
    } else if (lastStatusCode==401) {
        error = @"Authentication failed (try again or check your username and password)";
    } else {
        error = [NSString stringWithFormat:@"server failed with error code %d",lastStatusCode];
    }
    
    BOOL handled = completionFunction&&completionFunction(serviceCallResult,*lastErrorParsed);
    
    if (error&&delegate&&[(id)delegate respondsToSelector:@selector(reportError:forService:)]&&!handled) {
        [delegate reportError:error forService:self];
    }
    
    if (delegate) {
		NSLog(@"(%d) Service complete, calling the delegate with result %d",serviceCallId,serviceCallResult);
		[delegate serviceHasFinishedWithResult:serviceCallResult forService:self];
	}
    
    *lastErrorParsed = error;
}

#pragma mark - NSURLConnectionDelegate

- (void)connection:(NSURLConnection *)connection
didReceiveResponse:(NSURLResponse *)response {
	NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
	NSLog(@"(%d) response - web service %@ with status %ld, data may follow",serviceCallId,serviceCallName,(long)[httpResponse statusCode]);
	
	expectedContentLength = [response expectedContentLength];
	lastStatusCode = [httpResponse statusCode];
	
	if (delegate&&[(id)delegate respondsToSelector:@selector(responseHeaderReceivedWithStatusCode:forService:)]) {
		[delegate responseHeaderReceivedWithStatusCode:lastStatusCode forService:self];			
	}
	
	if ([httpResponse textEncodingName]) {
		NSLog(@"(%d) encoding %@",serviceCallId,[httpResponse textEncodingName]);
		outputEncoding = [[NSString alloc] initWithString:[httpResponse textEncodingName]];
	}
}

- (void)connection:(NSURLConnection *)connection
	didReceiveData:(NSData *)data {
    
	NSString *connectionDataNextPacket = nil;
	if (lastStatusCode==401) {
		return; // not authenticated, error message to follow
	}
    
	if (outputEncoding&&[@"utf8" caseInsensitiveCompare:outputEncoding]==NSOrderedSame) {
		// UTF8
		connectionDataNextPacket = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	} else if (outputEncoding&&[@"us-ascii" caseInsensitiveCompare:outputEncoding]==NSOrderedSame) {
		connectionDataNextPacket = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];		
	} else {
		// assume ISO 8859-1 (http 1.1 default)
		connectionDataNextPacket = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];		
	}
	
	if (!connectionDataNextPacket) {
		NSLog(@"(%d) **ERROR: undecodable data arrived**",serviceCallId);
		return;
	}
	
	if (dataReceived) { // we already have data
		NSString *newServiceOutput = [serviceOutput stringByAppendingString:connectionDataNextPacket];
		NSString *oldServiceOutput = serviceOutput;
		serviceOutput = [newServiceOutput retain];
		[oldServiceOutput release];
		[connectionDataNextPacket release];
	} else {
		serviceOutput = connectionDataNextPacket;
	}
	
	dataReceived = YES;
}

-                (void)connection:(NSURLConnection *)connection
didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
	NSLog(@"(%d) challenge received: %@ with failure count %ld",serviceCallId,challenge,(long)[challenge previousFailureCount]);
	if ([challenge previousFailureCount]<3&&username) {
		NSLog(@"(%d) responding with username %@ and password %@ with session persistence",serviceCallId,username,[password md5hash]);
		[[challenge sender] useCredential:[NSURLCredential
										   credentialWithUser:[NSString stringWithString:username]
                                           password:[password md5hash]
                                           persistence:NSURLCredentialPersistenceNone]
               forAuthenticationChallenge:challenge];
	} else {
		authFailed = YES;
		[[challenge sender] cancelAuthenticationChallenge:challenge];
	}
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	NSLog(@"(%d) finished service load with status code %d", serviceCallId, lastStatusCode);
	
	inProgress = NO;
	complete = YES;
	NSString *lastErrorParsed = nil;

	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
	
	if ([serviceOutput length]<expectedContentLength) {
		NSLog(@"(%d) **WARNING: expected length not reached**, expected:%lld got:%lu",serviceCallId,expectedContentLength,(unsigned long)[serviceOutput length]);
	}
	
	if (lastStatusCode<300) {
        [self parseSuccessfulCompletionOfService:&lastErrorParsed];
	} else {
        [self parseErrorCompletionOfService:&lastErrorParsed];
	}

	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
}

- (void)connection:(NSURLConnection *)connection
  didFailWithError:(NSError *)error {
	NSLog(@"(%d) received connection fail",serviceCallId);
	
	succeededHTTP = NO;
	BOOL reported = NO;
    inProgress = NO;

	
	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;

	if (delegate) {
		[delegate serviceHasFinishedWithResult:NO forService:self];
	}

	if (completionFunction) {
		if (completionFunction(NO,[error localizedDescription])) {
			return;
		}
	}

	if (delegate&&[(id)delegate respondsToSelector:@selector(reportError:forService:)]) {
		reported = YES;

        if (authFailed) {
			[delegate reportError:@"Authentication failed (check your username and password)" forService:self];
			NSLog(@"authfail error detail : %@",[error localizedDescription]);
		} else {
			[delegate reportError:[error localizedDescription] forService:self];			
		}
	} else if (delegate&&[(id)delegate respondsToSelector:@selector(httpErrorOccurred:forService:)]) {
		reported = YES;
		[delegate httpErrorOccurred:[error localizedDescription] forService:self];
	}
	

	if (!reported) {
		NSLog(@"(%d) possibly unlogged/unshown error %@ on service type %@",serviceCallId,[error localizedDescription],self);
	}
}

@end
