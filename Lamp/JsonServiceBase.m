//
//  JsonServiceBase.m
//  Friend Finder
//
//  Created by Carl Peto on 11/04/2012.
//  Copyright (c) 2012 Petosoft. All rights reserved.
//

#import "JsonServiceBase.h"

extern NSString *serviceRoot;

@interface ServiceBase (Private)
-(void)parseErrorCompletionOfService:(NSString**)lastErrorParsed;
@end

@implementation JsonServiceBase

-(NSString*)firstErrorInParsedErrors {
    if (![self.errors count]) return @"no array error";
    if (![[self.errors objectAtIndex:0] respondsToSelector:@selector(initWithUTF8String:)]) return @"non string error";
    return [self.errors objectAtIndex:0];
}
-(void)parseSuccessfulCompletionOfService:(NSString**)lastErrorParsed {
    serviceCallResult = NO; // no answer means no
    if (serviceOutput) {
        NSData *serviceOutputData = [serviceOutput dataUsingEncoding:NSUTF8StringEncoding];
        NSError *error = nil;
        _output = [NSJSONSerialization JSONObjectWithData:serviceOutputData options:NSJSONReadingAllowFragments error:&error];
        if ([_output isKindOfClass:[NSDictionary class]]) {
            NSNumber *resultValue = [_output objectForKey:@"result"];
            BOOL result = [resultValue isKindOfClass:[NSNumber class]]&&[resultValue boolValue];
            NSLog(@"(%d) Result %d",serviceCallId,result);
            serviceCallResult=result;
            
            if (serviceCallResult) {
                [self serviceCompletedSuccessfully]; // this is overridden in subclasses to finalise processing of the service
            }

            NSString *errorMessage = [_output objectForKey:@"error"];
            if (errorMessage) {
                serviceCallResult = NO;
                self.errors = [NSArray arrayWithObject:errorMessage];
            }
            NSString *warningMessage = [_output objectForKey:@"warning"];
            if (warningMessage) {
                self.warnings = [NSArray arrayWithObject:warningMessage];
            }
        } else {
            _output = nil;
            NSString *erroar = [NSString stringWithFormat:@"failed to parse json string %@, possible parse errors %@",serviceOutput,error.localizedDescription];
            NSLog(@"%@",erroar);
            *lastErrorParsed = erroar;
        }
    }
    self.completionFunction(serviceCallResult,*lastErrorParsed);
}
@end