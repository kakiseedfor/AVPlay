//
//  AVPlayController.h
//  AVPlay
//
//  Created by kakiYen on 2019/9/4.
//  Copyright © 2019 kakiYen. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, AVPlayStatus) {
    AVPlayUnOpen,
    AVPlayOpened,
    AVPlayPlaying,
    AVPlayPause,
    AVPlayClosed,
};

@protocol AVPlayControllerProtocol <NSObject>

- (void)statusCallBack:(AVPlayStatus)status;

@end

@class UIView;
NS_ASSUME_NONNULL_BEGIN

@interface AVPlayController : NSObject

- (instancetype)init:(NSString *)filePath parentView:(UIView *)parentView delegate:(id<AVPlayControllerProtocol>)delegate;  //主线程

- (void)setParentView:(UIView *)parentView;

- (void)setAutoStart:(BOOL)autoStart;   //最好在打开控制器之前设置

- (void)restartAVPlay;  //重新打开控制器

- (void)openAVPlay; //打开控制器

- (void)resumeAVPlay;   //开始或继续控制器

- (void)closeAVPlay;    //关闭控制器

- (void)pauseAVPlay; //暂停控制器

@end

NS_ASSUME_NONNULL_END
