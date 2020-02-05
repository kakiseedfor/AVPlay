//
//  KVOManager.h
//  AVPlay
//
//  Created by kakiYen on 2019/12/26.
//  Copyright © 2019 kakiYen. All rights reserved.
//

#import "KVOObserve.h"

NS_ASSUME_NONNULL_BEGIN

@interface KVOManager : NSObject

+ (instancetype)shareManager;

- (void)addObserver:(id)observe
           observed:(id)observed
            keyPath:(NSString *)keyPath
        kvoCallBack:(KVOCallBack)kvoCallBack;

@end

NS_ASSUME_NONNULL_END
