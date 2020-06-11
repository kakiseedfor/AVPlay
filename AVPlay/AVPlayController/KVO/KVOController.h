//
//  KVOController.h
//  AVPlay
//
//  Created by kakiYen on 2020/2/26.
//  Copyright © 2020 kakiYen. All rights reserved.
//

#import <objc/runtime.h>
#import "KVOObserve.h"

NS_ASSUME_NONNULL_BEGIN

@interface KVOController : NSObject

- (void)addObserver:(id)original
            observe:(id)observe
         forKeyPath:(NSString *)keyPath
        kvoCallBack:(KVOCallBack)kvoCallBack;

- (void)removeOriginal:(id)observer;

- (BOOL)existObserve:(id)observer
         withKeyPath:(NSString *)keyPath;

@end

NS_ASSUME_NONNULL_END
