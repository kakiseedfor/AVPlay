//
//  Synchronizer.h
//  AVPlay
//
//  Created by kakiYen on 2019/9/4.
//  Copyright © 2019 kakiYen. All rights reserved.
//

#import "Decoder.h"

NS_ASSUME_NONNULL_BEGIN

@protocol SynchronizerDelegate <NSObject>

- (void)statusCallBack:(DecoderStatus)status;

@optional
- (void)newCorrectVideoFrame:(Video_Frame *)videoFrame;

- (void)firstCorrectVideoFrame:(Video_Frame *)videoFrame;   //获取到第一帧视频进行一次回调

- (void)firstCorrectAudioFrame:(Audio_Frame *)audioFrame;   //获取到第一帧音频进行一次回调

- (void)completePlayVideoFrame;

@end

@interface Synchronizer : NSObject
@property (readonly, nonatomic) DecoderStatus status;
@property (readonly, nonatomic) BOOL endOfFile;

- (instancetype)initWith:(NSString *)filePath delegate:(id<SynchronizerDelegate>)delegate;

- (void)retrieveCallback:(SInt16 * _Nullable)ioData numberFrames:(UInt32)numberFrames numberChannels:(UInt32)numberChannels;

- (void)restartSynchronizer;    //重启同步器

- (void)openSynchronizer;  //打开同步器

- (void)pauseSynchronizer;   //暂停同步器

- (void)closeSynchronizer;  //关闭同步器

@end

NS_ASSUME_NONNULL_END
