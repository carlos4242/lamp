//
//  ServiceBase.m
//  Friend Finder
//
//  Created by carl peto on 29/07/2010.
//  Copyright 2010 Petosoft. All rights reserved.
//

#import "ServiceBase.h"

#import <CommonCrypto/CommonDigest.h>
#include <sys/time.h>

extern NSString *serviceRoot;

@implementation ServiceBase

-(void)setNetworkActivityIndicator:(BOOL)on {
#if (!SUPPRESS_NETWORK_ACTIVITY_INDICATOR)
    [UIApplication sharedApplication].networkActivityIndicatorVisible = on;
#endif
}

-(id)init {
    self = [super init];
	if (self) {
		dataReceived = NO;
		inProgress = NO;
		complete = NO;
		succeededHTTP = YES; // until we know otherwise
		serviceCallResult = NO; //until we know better
		_forceSynchronous = NO;
		serviceCallId = random()%1000;
		authFailed = NO;
    }
	return self;
}

-(NSURL*)getServiceUrlFromService:(NSString*)service {
	serviceCallName = [[NSString alloc] initWithString:service];
	NSString *urlString = [NSString stringWithFormat:@"%@%@",serviceRoot,service];
	NSLog(@"(%d) Sending url %@",serviceCallId,urlString);
	return [NSURL URLWithString:urlString];
}
-(NSMutableURLRequest*)requestForService:(NSString*)service postData:(NSString*)postData {
    NSURL *url = [self getServiceUrlFromService:service];
	NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc] initWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:10.0];
    [urlRequest setHTTPShouldHandleCookies:YES];
    [urlRequest setTimeoutInterval:3];
    if (postData) {
        [urlRequest setHTTPMethod:@"POST"];
        [urlRequest setHTTPBody:[postData dataUsingEncoding:NSUTF8StringEncoding]];
    } else {
        [urlRequest setHTTPMethod:@"GET"];
    }
    return urlRequest;
}
-(BOOL)callService:(NSString*)service postData:(NSString*)postData {
    NSMutableURLRequest *urlRequest = [self requestForService:service postData:postData];
    if (![NSURLConnection canHandleRequest:urlRequest]) {
        NSLog(@"*** WARNING!! callservice cannot handle request for %@ (%@, url = %@) in %@",urlRequest,service,[self getServiceUrlFromService:service],self);
        self.completionFunction(NO,@"cannot handle request");
        return NO;
    }
    
    [self setNetworkActivityIndicator:YES];
    
    connection = [[NSURLConnection alloc] initWithRequest:urlRequest delegate:self startImmediately:NO];
    
    if (connection) {
        [connection start];
        inProgress = YES;
    } else {
        NSLog(@"*** WARNING!! callservice failed to create connection for %@ (%@, url = %@) in %@",urlRequest,service,[self getServiceUrlFromService:service],self);
        self.completionFunction(NO,@"cannot create request");
        return NO;
    }
    
#if (SUPPRESS_NETWORK_ACTIVITY_INDICATOR)
    NSLog(@"successfully created and started service %@, (%@)",self,service);
#endif
    return YES; // success
}

- (void)cancel {
	if (connection) {
		[connection cancel];
		NSLog(@"(%d) cancelled",serviceCallId);
        _completionFunction(NO,@"cancelled");
	}
	inProgress = NO;
}

-(void)serviceCompletedSuccessfully {
    gettimeofday(&lastSuccessfulNetworkCall,NULL);
}
-(void)parseSuccessfulCompletionOfService:(NSString**)lastErrorParsed {
    serviceCallResult = NO; // no answer means no
    if (serviceCallResult) {
		[self serviceCompletedSuccessfully]; // this is overridden in subclasses to finalise processing of the service
	}
    _completionFunction(serviceCallResult,*lastErrorParsed);
}
-(void)parseErrorCompletionOfService:(NSString**)lastErrorParsed {
    NSString *error = nil;
    serviceCallResult = NO;
    
    if (_lastStatusCode==500) {
        error = @"Internal server error.";
    } else if (_lastStatusCode==401) {
        error = @"Authentication failed (try again or check your username and password)";
    } else {
        error = [NSString stringWithFormat:@"server failed with error code %ld",(long)_lastStatusCode];
    }
    _completionFunction(serviceCallResult,*lastErrorParsed);
    *lastErrorParsed = error;
}

#pragma mark - NSURLConnectionDelegate

- (void)connection:(NSURLConnection *)connection
didReceiveResponse:(NSURLResponse *)response {
	NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
	NSLog(@"(%d) response - web service %@ with status %ld, data may follow",serviceCallId,serviceCallName,(long)[httpResponse statusCode]);
	
	expectedContentLength = [response expectedContentLength];
	_lastStatusCode = [httpResponse statusCode];
	
	if ([httpResponse textEncodingName]) {
		NSLog(@"(%d) encoding %@",serviceCallId,[httpResponse textEncodingName]);
		outputEncoding = [[NSString alloc] initWithString:[httpResponse textEncodingName]];
	}
}

- (void)connection:(NSURLConnection *)connection
	didReceiveData:(NSData *)data {
#if (SUPPRESS_NETWORK_ACTIVITY_INDICATOR)
    NSLog(@"data received on %@, (%@)",self,data);
#endif
    
	NSString *connectionDataNextPacket = nil;
	if (_lastStatusCode==401) {
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
		serviceOutput = newServiceOutput;
	} else {
		serviceOutput = connectionDataNextPacket;
	}
	
	dataReceived = YES;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	NSLog(@"(%d) finished service load with status code %ld", serviceCallId, (long)_lastStatusCode);
	inProgress = NO;
	complete = YES;
	NSString *lastErrorParsed = nil;
    [self setNetworkActivityIndicator:NO];
	if ([serviceOutput length]<expectedContentLength) {
		NSLog(@"(%d) **WARNING: expected length not reached**, expected:%lld got:%lu",serviceCallId,expectedContentLength,(unsigned long)[serviceOutput length]);
	}
	if (_lastStatusCode<300) {
        [self parseSuccessfulCompletionOfService:&lastErrorParsed];
	} else {
        [self parseErrorCompletionOfService:&lastErrorParsed];
	}
    [self setNetworkActivityIndicator:NO];
}

- (void)connection:(NSURLConnection *)connection
  didFailWithError:(NSError *)error {
	NSLog(@"(%d) received connection fail",serviceCallId);
	succeededHTTP = NO;
    inProgress = NO;
    [self setNetworkActivityIndicator:NO];
	_completionFunction(NO,[error localizedDescription]);
}

- (NSString*)description {
    return [NSString stringWithFormat:@"service class %@ call id %d",[self class],serviceCallId];
}

@end
