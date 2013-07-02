//
//  LampService.m
//  Lamp
//
//  Created by Carl Peto on 19/11/2012.
//  Copyright (c) 2012 Carl Peto. All rights reserved.
//

#import "LampService.h"

@implementation LampService


-(NSMutableURLRequest*)requestForService:(NSString*)service {
    
    serviceCallName = [[NSString alloc] initWithString:service];
	NSString *urlString = [NSString stringWithFormat:@"%@%@",serviceRoot,service];
	
    NSURL *url = [NSURL URLWithString:urlString];
	NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc] initWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:60.0];
    [urlRequest setHTTPShouldHandleCookies:YES];
    return urlRequest;
}

-(void)lampOneSetState:(BOOL)onOff {
    [super callService:onOff?@"a":@"b"];
}

-(void)lampTwoSetState:(BOOL)onOff {
    [super callService:onOff?@"c":@"d"];
}

-(void)checkState {
    [super callService:@""];
}

-(void)refreshState {
    [super callService:@""];
}

-(BOOL)lampOneIsOn {
    return [[output objectForKey:@"lamp1"] isKindOfClass:[NSNumber class]]&&[[output objectForKey:@"lamp1"] boolValue];
}

-(BOOL)lampTwoIsOn {
    return [[output objectForKey:@"lamp2"] isKindOfClass:[NSNumber class]]&&[[output objectForKey:@"lamp2"] boolValue];
}

@end