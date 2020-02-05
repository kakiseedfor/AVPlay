//
//  NSObject+KVOObject.m
//  LockProject
//
//  Created by kakiYen on 2019/3/30.
//  Copyright © 2019 kakiYe. All rights reserved.
//

#import "NSObject+KVOObject.h"

@implementation NSObject (KVOObject)

- (void)addObserver:(id)observe
         forKeyPath:(NSString *)keyPath
        kvoCallBack:(KVOCallBack)kvoCallBack
{
    [KVOManager.shareManager addObserver:observe observed:self keyPath:keyPath kvoCallBack:kvoCallBack];
}

@end
