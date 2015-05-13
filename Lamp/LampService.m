//
//  LampService.m
//  Lamp
//
//  Created by Carl Peto on 19/11/2012.
//  Copyright (c) 2012 Carl Peto. All rights reserved.
//

#import "LampService.h"
#include <ifaddrs.h>
#include <arpa/inet.h>

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

-(void)allOn {
    [super callService:@"1"];
}

-(void)allOff {
    [super callService:@"0"];
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

+(in_addr_t)getIPAddress {
    in_addr_t en0base = 0;
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    int success = 0;
    // retrieve the current interfaces - returns 0 on success
    success = getifaddrs(&interfaces);
    if (success == 0) {
        // Loop through linked list of interfaces
        temp_addr = interfaces;
        while(temp_addr != NULL) {
            if(temp_addr->ifa_addr->sa_family == AF_INET) {
                // Check if interface is en0 which is the wifi connection on the iPhone
                if([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"]) {
                    in_addr_t en0addr = ((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr.s_addr;
                    in_addr_t en0mask = ((struct sockaddr_in *)temp_addr->ifa_netmask)->sin_addr.s_addr;
                    en0base = en0addr & en0mask;
                }
            }
            temp_addr = temp_addr->ifa_next;
        }
    }
    // Free memory
    freeifaddrs(interfaces);
    return en0base;
}

@end