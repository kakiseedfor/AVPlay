//
//  NSDate+String.m
//  AVPlay
//
//  Created by kakiYen on 2019/11/9.
//  Copyright © 2019 kakiYen. All rights reserved.
//

#import "NSDate+String.h"

@implementation NSDate (String)

- (NSString *)formatToString{
    return [self formatToString:@"yyyyMMddHHmmss"];
}

- (NSString *)formatToString:(NSString *)format{
    return [self formatToString:format timeZone:nil];
}

- (NSString *)formatToString:(NSString *)format timeZone:(NSString *)zone{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = format;
    
    if (zone.length) {
        NSTimeZone * timeZone = [NSTimeZone timeZoneWithName:zone];
        [formatter setTimeZone:timeZone];
    }
    
    return [formatter stringFromDate:self];
}

@end
