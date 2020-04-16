//
//  KVOObserve.m
//  AVPlay
//
//  Created by kakiYen on 2019/10/29.
//  Copyright © 2019 kakiYen. All rights reserved.
//

#import "KVOObserve.h"

@implementation KVOObserve

- (void)dealloc{
    NSLog(@"%s",__FUNCTION__);
}

+ (instancetype)shareInstance{
    static dispatch_once_t onceToken;
    static KVOObserve *observe = nil;
    dispatch_once(&onceToken, ^{
        observe = [[KVOObserve alloc] init];
    });
    return observe;
}

/**
 KVO的回调线程现场是根据注册KVO时的所在线程
 */
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    KVOInfo *info = (__bridge KVOInfo *)(context);
    if (!info.observe) {
        return;
    }
    
    id oldValue = change[NSKeyValueChangeOldKey];
    id newValue = change[NSKeyValueChangeNewKey];
    
    BOOL should = NO;
    if ([oldValue isKindOfClass:NSNumber.class] && [newValue isKindOfClass:NSNumber.class]) {
        should = [oldValue isEqualToNumber:newValue];
    }else if ([oldValue isKindOfClass:NSValue.class] && [newValue isKindOfClass:NSValue.class]){
        should = [oldValue isEqualToValue:newValue];
    }else if ([oldValue isKindOfClass:NSString.class] && [newValue isKindOfClass:NSString.class]){
        should = [oldValue isEqualToString:newValue];
    }else if ([oldValue isKindOfClass:NSDate.class] && [newValue isKindOfClass:NSDate.class]){
        should = [oldValue isEqualToDate:newValue];
    }else if ([oldValue isKindOfClass:NSArray.class] && [newValue isKindOfClass:NSArray.class]){
        should = [oldValue isEqualToArray:newValue];
    }else if ([oldValue isKindOfClass:NSDictionary.class] &&
              [newValue isKindOfClass:NSDictionary.class]){
        should = [oldValue isEqualToDictionary:newValue];
    }else{
        should = [oldValue isEqual:newValue];
    }
    
    //相同值将不回调
    if (should) {
        return;
    }
    
    !info.callBack ? : info.callBack(newValue ? newValue : oldValue, [change[NSKeyValueChangeKindKey] unsignedIntegerValue], change[NSKeyValueChangeIndexesKey]);
}

@end
