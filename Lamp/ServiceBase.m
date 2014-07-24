//
//  ServiceBase.m
//  Friend Finder
//
//  Created by carl peto on 29/07/2010.
//  Copyright 2010 Petosoft. All rights reserved.
//

#import "ServiceBase.h"
#import <CommonCrypto/CommonDigest.h>
#import "NSData+Base64.h"
#include <sys/time.h>

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
	NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc] initWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:60.0];
    [urlRequest setHTTPShouldHandleCookies:YES];
	[urlRequest setHTTPMethod:@"POST"];
    [urlRequest setTimeoutInterval:3];
    return urlRequest;
}
-(BOOL)callService:(NSString*)service  {
    NSMutableURLRequest *urlRequest = [self requestForService:service];
    [urlRequest setHTTPBody:[[self requestBody] dataUsingEncoding:NSASCIIStringEncoding]];
    if (![NSURLConnection canHandleRequest:urlRequest]) {
        NSLog(@"*** WARNING!! callservice cannot handle request for %@ (%@, url = %@) in ",urlRequest,service,[self getServiceUrlFromService:service],self);
        return NO;
    }
    
    [self setNetworkActivityIndicator:YES];
    
    connection = [[NSURLConnection alloc] initWithRequest:urlRequest delegate:self startImmediately:NO];
    
    if (connection) {
        [connection start];
        inProgress = YES;
    } else {
        NSLog(@"*** WARNING!! callservice failed to create connection for %@ (%@, url = %@) in %@",urlRequest,service,[self getServiceUrlFromService:service],self);
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
	}
	
	inProgress = NO;
}

-(void)serviceCompletedSuccessfully {
    gettimeofday(&lastSuccessfulNetworkCall,NULL);
}
-(void)handleErrorsInCompletedResult:(NSString**)lastErrorParsed {
    if ([_delegate respondsToSelector:@selector(errorsOccurred:forService:)]) {
        [_delegate errorsOccurred:_errors forService:self];
    }
}
-(void)handleWarningsInCompletedResult {
    if ([_delegate respondsToSelector:@selector(warningsOccured:forService:)]) {
        [_delegate warningsOccured:_warnings forService:self];
    } else {
        NSLog(@"unlogged warnings on service %@",_warnings);
    }
}
-(void)parseSuccessfulCompletionOfService:(NSString**)lastErrorParsed {
    serviceCallResult = NO; // no answer means no
    
    if (serviceCallResult) {
		[self serviceCompletedSuccessfully]; // this is overridden in subclasses to finalise processing of the service
	}

    BOOL handled = _completionFunction&&_completionFunction(serviceCallResult,*lastErrorParsed);

    if (!_delegate&&!handled) {
        NSLog(@"service finished with no delegate set, errors and warnings will not show");
    }
    
    if (_delegate&&!handled) {
		NSLog(@"(%d) Service complete, calling the delegate with result %d",serviceCallId,serviceCallResult);
		[_delegate serviceHasFinishedWithResult:serviceCallResult forService:self];
	}
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
    
    BOOL handled = _completionFunction&&_completionFunction(serviceCallResult,*lastErrorParsed);
    
    if (error&&_delegate&&[_delegate respondsToSelector:@selector(reportError:forService:)]&&!handled) {
        [_delegate reportError:error forService:self];
    }
    
    if (_delegate) {
		NSLog(@"(%d) Service complete, calling the delegate with result %d",serviceCallId,serviceCallResult);
		[_delegate serviceHasFinishedWithResult:serviceCallResult forService:self];
	}
    
    *lastErrorParsed = error;
}

#pragma mark - NSURLConnectionDelegate

- (void)connection:(NSURLConnection *)connection
didReceiveResponse:(NSURLResponse *)response {
	NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
	NSLog(@"(%d) response - web service %@ with status %ld, data may follow",serviceCallId,serviceCallName,(long)[httpResponse statusCode]);
	
	expectedContentLength = [response expectedContentLength];
	_lastStatusCode = [httpResponse statusCode];
	
	if (_delegate&&[_delegate respondsToSelector:@selector(responseHeaderReceivedWithStatusCode:forService:)]) {
		[_delegate responseHeaderReceivedWithStatusCode:_lastStatusCode forService:self];
	}
	
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
	BOOL reported = NO;
    inProgress = NO;

    [self setNetworkActivityIndicator:NO];

	if (_delegate) {
		[_delegate serviceHasFinishedWithResult:NO forService:self];
	}

	if (_completionFunction) {
		if (_completionFunction(NO,[error localizedDescription])) {
			return;
		}
	}

	if (_delegate&&[_delegate respondsToSelector:@selector(reportError:forService:)]) {
		reported = YES;

        if (authFailed) {
			[_delegate reportError:@"Authentication failed (check your username and password)" forService:self];
			NSLog(@"authfail error detail : %@",[error localizedDescription]);
		} else {
			[_delegate reportError:[error localizedDescription] forService:self];
		}
	} else if (_delegate&&[_delegate respondsToSelector:@selector(httpErrorOccurred:forService:)]) {
		reported = YES;
		[_delegate httpErrorOccurred:[error localizedDescription] forService:self];
	}
	

	if (!reported) {
		NSLog(@"(%d) possibly unlogged/unshown error %@ on service type %@",serviceCallId,[error localizedDescription],self);
	}
}

- (NSString*)description {
    return [NSString stringWithFormat:@"service class %@ call id %d",[self class],serviceCallId];
}

@end
