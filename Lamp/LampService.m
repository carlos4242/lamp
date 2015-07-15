//
//  LampService.m
//  Lamp
//
//  Created by Carl Peto on 19/11/2012.
//  Copyright (c) 2012 Carl Peto. All rights reserved.
//

#import "LampService.h"
#import "Reachability.h"
#include <ifaddrs.h>
#include <arpa/inet.h>

NSString *serviceRoot;
struct in_addr homeen0base;

@implementation LampService

+(void)initialize {
    serviceRoot = @"http://" kArduinoIPAddress "/";
    if (!inet_aton(kArduinoIPAddress, &homeen0base)) {
        NSLog(@"Failed to read arduino address, check the format of the address string");
        homeen0base.s_addr = 0;
    }
}

-(NSMutableURLRequest*)requestForService:(NSString*)service {
    serviceCallName = [[NSString alloc] initWithString:service];
	NSString *urlString = [NSString stringWithFormat:@"%@%@",serviceRoot,service];
	
    NSURL *url = [NSURL URLWithString:urlString];
	NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc] initWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:60.0];
    [urlRequest setHTTPShouldHandleCookies:YES];
    return urlRequest;
}

-(void)lampOneSetState:(BOOL)onOff {
    [super callService:@"lights/light1" postData:[NSString stringWithFormat:@"on=%d",onOff]];
}

-(void)lampTwoSetState:(BOOL)onOff {
    [super callService:@"lights/light2" postData:[NSString stringWithFormat:@"on=%d",onOff]];
}

-(void)lampThreeSetState:(BOOL)onOff {
    [super callService:@"lights/light3" postData:[NSString stringWithFormat:@"on=%d",onOff]];
}

-(void)allOn {
    [super callService:@"lights" postData:@"allOn=1"];
}

-(void)allOff {
    [super callService:@"lights" postData:@"allOff=1"];
}

-(BOOL)checkState {
    return [super callService:@"lights" postData:nil];
}

-(BOOL)refreshState {
    return [super callService:@"lights" postData:nil];
}

-(OptionalBool)lampOneIsOn {
    if ([self.output[@"lamp1"] isKindOfClass:[NSNumber class]]) {
        return [self.output[@"lamp1"] boolValue];
    } else {
        return undefined;
    }
}

-(OptionalBool)lampTwoIsOn {
    if ([self.output[@"lamp2"] isKindOfClass:[NSNumber class]]) {
        return [self.output[@"lamp2"] boolValue];
    } else {
        return undefined;
    }
}

-(OptionalBool)lampThreeIsOn {
    if ([self.output[@"lamp3"] isKindOfClass:[NSNumber class]]) {
        return [self.output[@"lamp3"] boolValue];
    } else {
        return undefined;
    }
}

+(BOOL)onHomeNetwork {
    return [self IPAddressMatchesBase:homeen0base.s_addr];
}

+(BOOL)onWifi {
    return [Reachability sharedWifiReachability].currentReachabilityStatus != NotReachable;
}

+(BOOL)IPAddressMatchesBase:(in_addr_t)ipToMatch {
    BOOL matches = false;
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
                    in_addr_t en0base = en0addr & en0mask;
                    in_addr_t maskedIP = ipToMatch & en0mask;
                    matches = en0base == maskedIP;
                }
            }
            temp_addr = temp_addr->ifa_next;
        }
    }
    // Free memory
    freeifaddrs(interfaces);
    return matches;
}

@end