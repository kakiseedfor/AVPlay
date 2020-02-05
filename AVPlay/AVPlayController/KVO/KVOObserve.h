//
//  KVOObserve.h
//  AVPlay
//
//  Created by kakiYen on 2019/10/29.
//  Copyright © 2019 kakiYen. All rights reserved.
//

#import "KVOInfo.h"

NS_ASSUME_NONNULL_BEGIN

@interface KVOObserve : NSObject
@property (weak, readonly, nonatomic) id observed;  //被观察的对象

- (instancetype)initWith:(id)observed;

- (void)addObserver:(id)observe
            keyPath:(NSString *)keyPath
        kvoCallBack:(KVOCallBack)kvoCallBack;

- (void)updateKVOObserve;

@end

NS_ASSUME_NONNULL_END
