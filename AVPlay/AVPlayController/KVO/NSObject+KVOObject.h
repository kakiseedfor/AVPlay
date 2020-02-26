//
//  NSObject+KVOObject.h
//  LockProject
//
//  Created by kakiYen on 2019/3/30.
//  Copyright © 2019 kakiYen. All rights reserved.
//

#import "KVOController.h"

@interface NSObject (KVOObject)

- (void)addObserver:(id)observe
         forKeyPath:(NSString *)keyPath
        kvoCallBack:(KVOCallBack)kvoCallBack;

@end
