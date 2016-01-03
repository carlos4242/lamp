//
//  LampService.m
//  Lamp
//
//  Created by Carl Peto on 19/11/2012.
//  Copyright (c) 2012 Carl Peto. All rights reserved.
//

// GET /   ... get web code
// GET /lights   ... get json of lights status
// GET /lights/light1   ...   get json of single light status
// POST /lights  ...  allOn=1 ... turn all lights on and return json of lights status
// POST /lights  ...  allOff=1 ... turn all lights off and return json of lights status
// POST /lights/light2  ...  on=x  ... turn lights on or off (1 and 0 are only recognized values) returns json of single light status

// {\"1\":X,\"2\":X,\"3\":X}

/*
 const int webHeaderLength = 43;
 const PROGMEM char webHeader[] =
 "HTTP/1.0 200 OK\r\nContent-Type: text/html\r\n\r\n";
 
 const int website1Length = 79;
 const PROGMEM char website1[] =
 "<link rel='stylesheet' type='text/css' href='http://10.0.1.170:3000/lights.css'>";
 
 const int website1aLength = 101;
 const PROGMEM char website1a[] =
 "<div id='pageTitle'>light control</div><div><p>Tube Lamp : <input type='checkbox' id='lamp2' disabled ";
 
 const int website2Length = 63;
 const PROGMEM char website2[] =
 "></p><p>Round Lamp : <input type='checkbox' id='lamp1' disabled ";
 
 const int website3Length = 64;
 const PROGMEM char website3[] =
 "></p><p>Corner Lamp : <input type='checkbox' id='lamp3' disabled ";
 
 const int website4Length = 88;
 const PROGMEM char website4[] =
 "><p></div><script src='https://ajax.googleapis.com/ajax/libs/jquery/2.1.4/jquery.min.js'>";
 
 const int website4aLength = 64;
 const PROGMEM char website4a[] =
 "</script><script src='http://10.0.1.170:3000/lights.js'></script>";
 
 
 
 
 void writeWebServiceReply(EthernetClient client, const char * output) {
 static const char * header = "HTTP/1.0 200 OK\r\nContent-Type: text/plain\r\n\r\n";
 static const int headerLength = strlen(header);
 static char htmlReply[100];
 char * htmlReplyPointer = htmlReply;
 strncpy(htmlReplyPointer, header, headerLength);
 htmlReplyPointer += headerLength;
 int outputLength = strlen(output);
 strncpy(htmlReplyPointer, output, outputLength);
 htmlReplyPointer += outputLength;
 int htmlReplyLength = htmlReplyPointer - htmlReply;
 client.write((byte*)htmlReply, htmlReplyLength);
 }
 
 const char * getLightStatus(int light) {
 int lightStatus;
 if (light == 1) {
 lightStatus = lightOneState;
 }
 else if (light == 2) {
 lightStatus = lightTwoState;
 }
 else if (light == 3) {
 lightStatus = lightThreeState;
 }
 else {
 return "invalid";
 }
 
 static char statusBuffer[statusBufferLen];
 
 char * buffer = statusBuffer;
 
 strncpy(buffer, "{\"", 2);
 buffer += 2;
 *buffer = 48 + light;
 buffer += 1;
 strncpy(buffer, "\":X}", 5);
 buffer[2] = 48 + lightStatus;
 return statusBuffer;
 }
 
 */

#import "LampService.h"
#import "Reachability.h"
#include <ifaddrs.h>
#include <arpa/inet.h>

NSString *serviceRoot;
struct in_addr homeen0base;

@implementation LampService

static BOOL wifiReachabilityKnown = false;
static BOOL arduinoReachabilityKnown = false;
static BOOL onwifi;
static BOOL arduinoReachable;

+(void)initialize {
    serviceRoot = @"http://" kArduinoIPAddress "/";
    if (!inet_aton(kArduinoIPAddress, &homeen0base)) {
        NSLog(@"Failed to read arduino address, check the format of the address string");
        homeen0base.s_addr = 0;
    }
    [[Reachability sharedWifiReachability] getStatus:^(NetworkStatus status) {
        onwifi = status != NotReachable;
        wifiReachabilityKnown = YES;
    }];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reachabilityChange:) name:kReachabilityChangedNotification object:nil];
    [[Reachability sharedWifiReachability] startNotifer];
    [[Reachability sharedArduinoReachability] getStatus:^(NetworkStatus status) {
        arduinoReachable = status != NotReachable;
        arduinoReachabilityKnown = YES;
    }];
    [[Reachability sharedArduinoReachability] startNotifer];
}

+(void)reachabilityChange:(NSNotification*)notification {
    if (notification.object == [Reachability sharedWifiReachability]) {
        onwifi = ((Reachability*)notification.object).currentReachabilityStatus != NotReachable;
    } else if (notification.object == [Reachability sharedArduinoReachability]) {
        arduinoReachable = ((Reachability*)notification.object).currentReachabilityStatus != NotReachable;
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
    [super callService:@"lights/1" postData:[NSString stringWithFormat:@"on=%d",!onOff]];
}

-(void)lampTwoSetState:(BOOL)onOff {
    [super callService:@"lights/2" postData:[NSString stringWithFormat:@"on=%d",!onOff]];
}

-(void)lampThreeSetState:(BOOL)onOff {
    [super callService:@"lights/3" postData:[NSString stringWithFormat:@"on=%d",!onOff]];
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
    if ([self.output[@"1"] isKindOfClass:[NSNumber class]]) {
        return ![self.output[@"1"] boolValue];
    } else {
        return undefined;
    }
}

-(OptionalBool)lampTwoIsOn {
    if ([self.output[@"2"] isKindOfClass:[NSNumber class]]) {
        return ![self.output[@"2"] boolValue];
    } else {
        return undefined;
    }
}

-(OptionalBool)lampThreeIsOn {
    if ([self.output[@"3"] isKindOfClass:[NSNumber class]]) {
        return ![self.output[@"3"] boolValue];
    } else {
        return undefined;
    }
}

+(BOOL)onHomeNetwork {
    return [self IPAddressMatchesBase:homeen0base.s_addr];
}

+(BOOL)onWifi {
    return onwifi;
}

+(BOOL)arduinoReachable {
    return arduinoReachable;
}

+(BOOL)wifiReachabilityKnown {
    return wifiReachabilityKnown;
}

+(BOOL)arduinoReachabilityKnown {
    return arduinoReachabilityKnown;
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