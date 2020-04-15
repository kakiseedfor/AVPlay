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
@property (weak, nonatomic) id originalObj;

@end

@implementation KVOController

- (void)dealloc
{
    NSLog(@"%s",__FUNCTION__);
    [self removeAllObserver];
}

- (instancetype)initWith:(id)originalObj
{
    self = [super init];
    if (self) {
        _kvoInfos = [NSMutableSet setWithCapacity:1];
        _originalObj = originalObj;
    }
    return self;
}

- (void)addObserver:(id)observe
         forKeyPath:(NSString *)keyPath
        kvoCallBack:(KVOCallBack)kvoCallBack
{
    //属性不存在
    if (![self verifyKeyPath:keyPath]) {
        return;
    }
    
    //属性已注册
    if ([self existObserve:observe withKeyPath:keyPath]) {
        return;
    }
    
    KVOInfo *kvoInfo = [[KVOInfo alloc] initWith:observe keyPath:keyPath kvoCallBack:kvoCallBack];
    [_kvoInfos addObject:kvoInfo];
    
    [_originalObj addObserver:KVOObserve.shareInstance forKeyPath:kvoInfo.keyPath options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:(__bridge void * _Nullable)kvoInfo];
}

- (void)removeAllObserver{
    for (KVOInfo *obj in _kvoInfos) {
        [_originalObj removeObserver:KVOObserve.shareInstance forKeyPath:obj.keyPath];
    }
    [_kvoInfos removeAllObjects];
}

- (void)removeObserver:(NSObject *)observer withKeyPath:(NSString *)keyPath{
    KVOInfo *kvoInfo = [[KVOInfo alloc] initWith:observer keyPath:keyPath];
    [_kvoInfos removeObject:kvoInfo];
    [_originalObj removeObserver:KVOObserve.shareInstance forKeyPath:keyPath];
}

- (BOOL)verifyKeyPath:(NSString *)keyPath{
    __block id tempObserved = _originalObj;
    __block BOOL should = NO;
    
    NSArray *keyPaths = [keyPath componentsSeparatedByString:@"."];
    [keyPaths enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        unsigned int count = 0;
        objc_property_t *propertyList = class_copyPropertyList([tempObserved class], &count);
        
        for (int i = 0; i < count; i++) {
            const char *attributes = property_getName(propertyList[i]);
            if (strcmp(attributes, keyPath.UTF8String) == 0) {
                should = YES;
                break;
            }
        }
        free(propertyList);
        
        if (should) {
            //获取下个实例变量。
            Ivar nextIvar = class_getInstanceVariable([tempObserved class], obj.UTF8String);
            tempObserved = object_getIvar(tempObserved, nextIvar);
        }
        
        *stop = !should;
    }];
    
    return should;
}

- (BOOL)existObserve:(id)observer withKeyPath:(NSString *)keyPath{
    KVOInfo *kvoInfo = [[KVOInfo alloc] initWith:observer keyPath:keyPath];
    return [_kvoInfos containsObject:kvoInfo];
}

- (void)didReleaseObserve:(KVOInfo *_Nonnull)info{
    if (!info.observe) {
        [self removeObserver:info.observe withKeyPath:info.keyPath];
    }
}

@end
