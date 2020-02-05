//
//  KVOInfo.h
//  AVPlay
//
//  Created by kakiYen on 2019/10/29.
//  Copyright © 2019 kakiYen. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^KVOCallBack)(id _Nullable context, NSKeyValueChange valueChange, NSIndexSet * _Nullable indexes);

NS_ASSUME_NONNULL_BEGIN

@interface KVOInfo : NSObject
@property (weak, readonly, nonatomic) id observe;   //观察的对象
@property (copy, readonly, nonatomic) KVOCallBack callBack; //KVO回调
@property (strong, readonly, nonatomic) NSString *keyPath;  //监听路径

- (instancetype)initWith:(id)observe keyPath:(NSString *)keyPath kvoCallBack:(KVOCallBack)kvoCallBack;

@end

NS_ASSUME_NONNULL_END
