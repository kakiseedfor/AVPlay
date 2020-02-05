//
//  KVOManager.m
//  AVPlay
//
//  Created by kakiYen on 2019/12/26.
//  Copyright © 2019 kakiYen. All rights reserved.
//

#import <objc/runtime.h>
#import "KVOManager.h"

@interface KVOManager (){
    CFRunLoopObserverRef _observerRef;
}
@property (strong, nonatomic) NSMutableArray<KVOObserve *> *kvoObserves;
@property (strong, nonatomic) NSMutableArray<KVOObserve *> *removeKVOObserves;

@end

@implementation KVOManager

- (instancetype)init
{
    self = [super init];
    if (self) {
        _kvoObserves = [NSMutableArray array];
        _removeKVOObserves = [NSMutableArray array];
        
        @weakify(self);
        _observerRef = CFRunLoopObserverCreateWithHandler(kCFAllocatorDefault, kCFRunLoopBeforeWaiting | kCFRunLoopExit, YES, INT_MAX, ^(CFRunLoopObserverRef observer, CFRunLoopActivity activity) {
            @strongify(self);
            [self updateKVOObserves];
        });
        CFRunLoopAddObserver(CFRunLoopGetCurrent(), _observerRef, kCFRunLoopCommonModes);
    }
    return self;
}

+ (instancetype)shareManager{
    static dispatch_once_t dispatchOnce;
    
    static KVOManager *manager = nil;
    dispatch_once(&dispatchOnce, ^{
        manager = [[KVOManager alloc] init];
    });
    return manager;
}

- (void)addObserver:(id)observe
           observed:(id)observed
            keyPath:(NSString *)keyPath
        kvoCallBack:(KVOCallBack)kvoCallBack
{
    if (![self verifyKeyPath:keyPath observed:observed]) {
        NSLog(@"There has no keyPath with \"%@\"",keyPath);
        return;
    }
    
    KVOObserve *kvoObserve = [self retriveObserved:observed];
    [kvoObserve addObserver:observe keyPath:keyPath kvoCallBack:kvoCallBack];
}

- (void)updateKVOObserves{
    [_kvoObserves enumerateObjectsUsingBlock:^(KVOObserve * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [obj updateKVOObserve];
        
        obj.observed ? : [self.removeKVOObserves addObject:obj];
    }];
    
    [_kvoObserves removeObjectsInArray:_removeKVOObserves];
    [_removeKVOObserves removeAllObjects];
}

- (BOOL)verifyKeyPath:(NSString *)keyPath observed:(id)observed{
    __block id tempObserved = observed;
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
        
        if (should) {
            //获取下个实例变量。
            Ivar nextIvar = class_getInstanceVariable([tempObserved class], obj.UTF8String);
            tempObserved = object_getIvar(tempObserved, nextIvar);
        }
        
        *stop = !should;
    }];
    
    return should;
}

- (KVOObserve *)retriveObserved:(id)observed{
    __block KVOObserve *kvoObserve = nil;
    [_kvoObserves enumerateObjectsUsingBlock:^(KVOObserve * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj.observed isEqual:observed]) {
            kvoObserve = obj;
            *stop = YES;
        }
    }];
    
    if (!kvoObserve) {
        kvoObserve = [[KVOObserve alloc] initWith:observed];
        [_kvoObserves addObject:kvoObserve];
    }
    return kvoObserve;
}

@end
