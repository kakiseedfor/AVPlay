//
//  NSObject+KVOObject.h
//  LockProject
//
//  Created by kakiYen on 2019/3/30.
//  Copyright © 2019 kakiYe. All rights reserved.
//

#import "KVOManager.h"

@interface NSObject (KVOObject)

- (void)addObserver:(id)observe
         forKeyPath:(NSString *)keyPath
        kvoCallBack:(KVOCallBack)kvoCallBack;

@end
