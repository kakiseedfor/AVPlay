//
//  KVOController.m
//  AVPlay
//
//  Created by kakiYen on 2020/2/26.
//  Copyright © 2020 kakiYen. All rights reserved.
//

#import "KVOController.h"

@interface KVOController ()
@property (strong, nonatomic) NSMutableSet<KVOInfo *> *kvoInfos;

@end

@implementation KVOController

- (void)dealloc
{
    NSLog(@"%s",__FUNCTION__);
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _kvoInfos = [NSMutableSet setWithCapacity:1];
    }
    return self;
}

- (void)addObserver:(id)original
            observe:(id)observe
         forKeyPath:(NSString *)keyPath
        kvoCallBack:(KVOCallBack)kvoCallBack
{
    KVOInfo *kvoInfo = [[KVOInfo alloc] initWith:observe keyPath:keyPath kvoCallBack:kvoCallBack];
    [_kvoInfos addObject:kvoInfo];
    [original addObserver:KVOObserve.shareInstance forKeyPath:kvoInfo.keyPath options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:(__bridge void * _Nullable)kvoInfo];
}

- (void)removeOriginal:(id)original{
    for (KVOInfo *kvoInfo in _kvoInfos) {
        [original removeObserver:KVOObserve.shareInstance forKeyPath:kvoInfo.keyPath];
    }
    [_kvoInfos removeAllObjects];
}

- (BOOL)existObserve:(id)observer withKeyPath:(NSString *)keyPath{
    KVOInfo *kvoInfo = [[KVOInfo alloc] initWith:observer keyPath:keyPath];
    return [_kvoInfos containsObject:kvoInfo];
}

@end
