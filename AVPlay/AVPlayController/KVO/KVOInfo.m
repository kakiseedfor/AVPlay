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

- (instancetype)initWith:(id)observe keyPath:(NSString *)keyPath kvoCallBack:(KVOCallBack)kvoCallBack
{
    self = [super init];
    if (self) {
        _observe = observe;
        _keyPath = keyPath;
        _callBack = kvoCallBack;
    }
    return self;
}

@end
