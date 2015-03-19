//
//  LampService.m
//  Lamp
//
//  Created by Carl Peto on 19/11/2012.
//  Copyright (c) 2012 Carl Peto. All rights reserved.
//

#import "LampService.h"

NSString *serviceRoot = @"http://10.0.1.160/";

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

-(void)lampThreeSetState:(BOOL)onOff {
    [super callService:onOff?@"f":@"e"];
}

-(void)beedoBeedoSetState:(BOOL)onOff {
    [super callService:onOff?@"g":@"h"];
}

-(BOOL)checkState {
    return [super callService:@""];
}

-(BOOL)refreshState {
    return [super callService:@""];
}

-(BOOL)lampOneIsOn {
    return [self.output[@"lamp1"] isKindOfClass:[NSNumber class]]&&[self.output[@"lamp1"] boolValue];
}

-(BOOL)lampTwoIsOn {
    return [self.output[@"lamp2"] isKindOfClass:[NSNumber class]]&&[self.output[@"lamp2"] boolValue];
}

-(BOOL)lampThreeIsOn {
    return [self.output[@"lamp3"] isKindOfClass:[NSNumber class]]&&![self.output[@"lamp3"] boolValue];
}

-(BOOL)beedoBeedoIsOn {
    return [self.output[@"beedoBeedo"] isKindOfClass:[NSNumber class]]&&[self.output[@"beedoBeedo"] boolValue];
}

@end