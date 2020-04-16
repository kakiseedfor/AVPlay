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
    //属性不存在
    if (![self verifyKeyPath:original keyPath:keyPath]) {
        return;
    }
    
    //属性已注册
    if ([self existObserve:observe withKeyPath:keyPath]) {
        return;
    }
    
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

- (BOOL)verifyKeyPath:(id)original keyPath:(NSString *)keyPath{
    __block id tempObserved = original;
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

@end
