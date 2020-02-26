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

- (void)addObserver:(id)observe
         forKeyPath:(NSString *)keyPath
        kvoCallBack:(KVOCallBack)kvoCallBack
{
    [self.kvoController addObserver:observe forKeyPath:keyPath kvoCallBack:kvoCallBack];
}

- (void)setKvoController:(KVOController *)kvoController{
    objc_setAssociatedObject(self, NSObject_KVOController, kvoController, OBJC_ASSOCIATION_RETAIN);
}

- (KVOController *)kvoController{
    KVOController *tempKVOController = objc_getAssociatedObject(self, NSObject_KVOController);
    if (!tempKVOController) {
        tempKVOController = [[KVOController alloc] initWith:self];
        self.kvoController = tempKVOController;
    }
    return tempKVOController;
}

@end
