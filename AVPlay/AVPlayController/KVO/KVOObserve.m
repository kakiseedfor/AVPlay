//
//  KVOObserve.m
//  AVPlay
//
//  Created by kakiYen on 2019/10/29.
//  Copyright © 2019 kakiYen. All rights reserved.
//

#import "KVOObserve.h"

@interface KVOObserve ()
@property (strong, nonatomic) NSMutableArray<KVOInfo *> *kvoInfos;

@end

@implementation KVOObserve

- (void)dealloc{
    NSLog(@"%s",__FUNCTION__);
}

- (instancetype)initWith:(id)observed
{
    self = [super init];
    if (self) {
        _observed = observed;
        _kvoInfos = [NSMutableArray array];
    }
    return self;
}

- (void)updateKVOObserve{
    [self removeWithObserver:nil];
}

- (void)removeWithObserver:(id)observe{
    NSMutableArray *tempArray = [NSMutableArray array];
    [_kvoInfos enumerateObjectsUsingBlock:^(KVOInfo * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj.observe isEqual:observe]) {
            [tempArray addObject:obj];
            [self.observed removeObserver:self forKeyPath:obj.keyPath];
        }
    }];
    [_kvoInfos removeObjectsInArray:tempArray];
}

- (BOOL)existObserve:(id)observe withKeyPath:(NSString *)keyPath{
    __block BOOL exist = NO;
    [_kvoInfos enumerateObjectsUsingBlock:^(KVOInfo * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj.observe isEqual:observe] && [obj.keyPath isEqualToString:keyPath]) {
            exist = YES;
            *stop = YES;
        }
    }];
    return exist;
}

- (void)addObserver:(KVOInfo *)kvoInfo
{
    [_observed addObserver:self forKeyPath:kvoInfo.keyPath options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:(__bridge void * _Nullable)kvoInfo];
    [_kvoInfos addObject:kvoInfo];
}

- (void)addObserver:(id)observe
            keyPath:(NSString *)keyPath
        kvoCallBack:(KVOCallBack)kvoCallBack
{
    //不重复添加已有的观察者对应的路径
    if ([self existObserve:observe withKeyPath:keyPath]) {
        return;
    }
    
    KVOInfo *kvoInfo = [[KVOInfo alloc] initWith:observe keyPath:keyPath kvoCallBack:kvoCallBack];
    [self addObserver:kvoInfo];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    KVOInfo *info = (__bridge KVOInfo *)(context);
    if (!info.observe) {    //观察者对象已释放，不必再回调。
        return;
    }
    
    id oldValue = change[@"old"];
    id newValue = change[@"new"];
    
    BOOL should = NO;
    if ([oldValue isKindOfClass:NSNumber.class] && [newValue isKindOfClass:NSNumber.class]) {
        should = [oldValue isEqualToNumber:newValue];
    }else if ([oldValue isKindOfClass:NSValue.class] && [newValue isKindOfClass:NSValue.class]){
        should = [oldValue isEqualToValue:newValue];
    }else if ([oldValue isKindOfClass:NSString.class] && [newValue isKindOfClass:NSString.class]){
        should = [oldValue isEqualToString:newValue];
    }else if ([oldValue isKindOfClass:NSDate.class] && [newValue isKindOfClass:NSDate.class]){
        should = [oldValue isEqualToDate:newValue];
    }else if ([oldValue isKindOfClass:NSArray.class] && [newValue isKindOfClass:NSArray.class]){
        should = [oldValue isEqualToArray:newValue];
    }else if ([oldValue isKindOfClass:NSDictionary.class] &&
              [newValue isKindOfClass:NSDictionary.class]){
        should = [oldValue isEqualToDictionary:newValue];
    }else{
        should = [oldValue isEqual:newValue];
    }
    
    //相同值将不回调
    if (should) {
        return;
    }
    
    !info.callBack ? : info.callBack(newValue ? newValue : oldValue, [change[@"kind"] unsignedIntegerValue], change[@"indexes"]);
}

@end
