//
//  NSObject+KVOObject.m
//  LockProject
//
//  Created by kakiYen on 2019/3/30.
//  Copyright © 2019 kakiYen. All rights reserved.
//

#import "NSObject+KVOObject.h"
#import "KVOController.h"

void *NSObject_KVOController = @"NSObject_KVOController";

@interface NSObject ()
@property (strong, nonatomic) KVOController *kvoController;

@end

@implementation NSObject (KVOObject)

- (void)kvoDealloc{
    [self.kvoController removeOriginal:self];
    
    Class superClass = class_getSuperclass(self.class);
    void(*dealloc)(id, SEL) = (void (*)(id,SEL))class_getMethodImplementation(superClass, NSSelectorFromString(@"dealloc"));
    !dealloc ?: dealloc(self, NSSelectorFromString(@"dealloc"));
}

- (void)addObserver:(id)observe
         forKeyPath:(NSString *)keyPath
        kvoCallBack:(KVOCallBack)kvoCallBack
{
    __block id tempObserved = self;
    __block BOOL should = NO;
    __block NSString *path = keyPath;
    
    NSArray *keyPaths = [keyPath componentsSeparatedByString:@"."];
    [keyPaths enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (idx < keyPaths.count - 1) {
            IMP imp = [tempObserved methodForSelector:NSSelectorFromString(obj)];
            if (!imp) {
                NSLog(@"There is no get Method(%@) in %s",obj,object_getClassName(tempObserved));
                *stop = YES;
            }
            
            void *(*impFun)(id,SEL) = (void *(*)(id,SEL))imp;
            tempObserved = (__bridge id)impFun(tempObserved, NSSelectorFromString(obj));
        }else{
            NSString *setMethodString = [NSString stringWithFormat:@"set%@",obj.capitalizedString];
            IMP imp = [tempObserved methodForSelector:NSSelectorFromString(setMethodString)];
            if (!imp) {
                NSLog(@"There is no set Method(%@) in %s",setMethodString,object_getClassName(tempObserved));
                *stop = YES;
            }
            
            path = obj;
            should = YES;
        }
    }];
    
    //属性不存在
    if (!should) {
        return;
    }
    
    //属性已注册
    if ([self.kvoController existObserve:tempObserved withKeyPath:path]) {
        return;
    }
    
    NSString *kvoClassName = [NSString stringWithFormat:@"%sKVO",object_getClassName(tempObserved)];
    Class kvoClass = objc_getClass(kvoClassName.UTF8String);
    if (!kvoClass) {
        kvoClass = objc_allocateClassPair(object_getClass(tempObserved), kvoClassName.UTF8String, 0);
        objc_registerClassPair(kvoClass);
        
        Method kvoDeallocMethod = class_getInstanceMethod(self.class, @selector(kvoDealloc));
        BOOL success = class_addMethod(kvoClass, NSSelectorFromString(@"dealloc"), method_getImplementation(kvoDeallocMethod), method_getTypeEncoding(kvoDeallocMethod));
        if (!success) {
            NSLog(@"Add dealloc method fail for class %s",class_getName(kvoClass));
            return;
        }
    }
    object_setClass(tempObserved, kvoClass);
    
    [self.kvoController addObserver:tempObserved observe:observe forKeyPath:path kvoCallBack:kvoCallBack];
}


- (BOOL)verifyKeyPath:(id)original keyPath:(NSString *)keyPath{
    __block id tempObserved = original;
    __block BOOL should = NO;
    
    NSArray *keyPaths = [keyPath componentsSeparatedByString:@"."];
    [keyPaths enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (idx < keyPaths.count - 1) {
            IMP imp = [tempObserved methodForSelector:NSSelectorFromString(obj)];
            if (!imp) {
                NSLog(@"There is no get Method(%@) in %s",obj,object_getClassName(tempObserved));
                *stop = YES;
            }
            
            void *(*impFun)(id,SEL) = (void *(*)(id,SEL))imp;
            tempObserved = (__bridge id)impFun(tempObserved, NSSelectorFromString(obj));
        }else{
            NSString *setMethodString = [NSString stringWithFormat:@"set%@",obj.capitalizedString];
            IMP imp = [tempObserved methodForSelector:NSSelectorFromString(setMethodString)];
            if (!imp) {
                NSLog(@"There is no set Method(%@) in %s",setMethodString,object_getClassName(tempObserved));
                *stop = YES;
            }
            
            should = YES;
        }
    }];
    
    return should;
}

- (void)setKvoController:(KVOController *)kvoController{
    objc_setAssociatedObject(self, NSObject_KVOController, kvoController, OBJC_ASSOCIATION_RETAIN);
}

- (KVOController *)kvoController{
    KVOController *tempKVOController = objc_getAssociatedObject(self, NSObject_KVOController);
    if (!tempKVOController) {
        tempKVOController = [[KVOController alloc] init];
        self.kvoController = tempKVOController;
    }
    return tempKVOController;
}

@end
