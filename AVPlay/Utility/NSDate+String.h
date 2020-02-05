//
//  NSDate+String.h
//  AVPlay
//
//  Created by kakiYen on 2019/11/9.
//  Copyright © 2019 kakiYen. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSDate (String)

- (NSString *)formatToString;

- (NSString *)formatToString:(NSString *)format;

- (NSString *)formatToString:(NSString *)format timeZone:(NSString *_Nullable)timeZone;

@end

NS_ASSUME_NONNULL_END
