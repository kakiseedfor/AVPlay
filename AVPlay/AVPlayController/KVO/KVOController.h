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

- (instancetype)initWith:(id)originalObj;

- (void)addObserver:(id)observe
         forKeyPath:(NSString *)keyPath
        kvoCallBack:(KVOCallBack)kvoCallBack;

@end

NS_ASSUME_NONNULL_END
