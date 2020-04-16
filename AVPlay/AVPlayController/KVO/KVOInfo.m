//
//  KVOInfo.m
//  AVPlay
//
//  Created by kakiYen on 2019/10/29.
//  Copyright © 2019 kakiYen. All rights reserved.
//

#import "KVOInfo.h"

@implementation KVOInfo

- (void)dealloc{
    NSLog(@"%s",__FUNCTION__);
}

- (NSUInteger)hash{
    return _keyPath.hash;
}

- (BOOL)isEqual:(KVOInfo *)object{
    BOOL should = NO;
    if (object) {
        should = [_observe isEqual:object.observe];
    }
    
    if (object.keyPath.length) {
        should = [_keyPath isEqualToString:object.keyPath];
    }
    return should;
}

- (instancetype)initWith:(id)observe keyPath:(NSString *)keyPath
{
    self = [super init];
    if (self) {
        _observe = observe;
        _keyPath = keyPath;
    }
    return self;
}

- (instancetype)initWith:(id)observe keyPath:(NSString *)keyPath kvoCallBack:(KVOCallBack)kvoCallBack
{
    self = [self initWith:observe keyPath:keyPath];
    if (self) {
        _callBack = kvoCallBack;
    }
    return self;
}

@end
