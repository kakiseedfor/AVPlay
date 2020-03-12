//
//  AVPlayController.m
//  AVPlay
//
//  Created by kakiYen on 2019/9/4.
//  Copyright © 2019 kakiYen. All rights reserved.
//

#import "AVPlayController.h"
#import "Synchronizer.h"
#import "VideoPlay.h"
#import "AudioPlay.h"

/*
 音视频的网络传输哪个好：
    TCP：基于流的传输；
        需要建立连接，所以传输效率较低；
        有重传机制，可以保证数据的完整性；
        直播中要求实时性高，重传机制会导致接收方卡帧。
    UPD：基于数据包的传输；
        无需建立连接，所以传输效率较高；
        无重传机制，不保证数据的完整性；
        直播中因为不考虑重传，所以接收方只需要处理好丢帧逻辑，可以保证实时性。
 */

@interface AVPlayController ()<AudioRenderProtocol, SynchronizerDelegate>
@property (weak, nonatomic) id<AVPlayControllerProtocol> delegate;
@property (strong, nonatomic) Synchronizer *synchronizer;
@property (strong, nonatomic) VideoPlay *videoPlay;
@property (strong, nonatomic) AudioPlay *audioPlay;
@property (nonatomic) BOOL autoStart;

@end

@implementation AVPlayController

- (void)dealloc{
    [self closeAVPlay];
    NSLog(@"%s",__FUNCTION__);
}

- (instancetype)init:(NSString *)filePath parentView:(UIView *)parentView delegate:(id<AVPlayControllerProtocol>)delegate
{
    self = [super init];
    if (self) {
        _delegate = delegate;
        _autoStart = YES;
        _videoPlay = [[VideoPlay alloc] init];
        _audioPlay = [[AudioPlay alloc] initWith:self];
        _synchronizer = [[Synchronizer alloc] initWith:filePath delegate:self];
        
        [self setParentView:parentView];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(applicationWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
        
        @weakify(self)
        [_videoPlay addObserver:self forKeyPath:@"status" kvoCallBack:^(NSNumber *_Nullable context, NSKeyValueChange valueChange, NSIndexSet * _Nullable indexes)
         {
             @strongify(self)
             if (context.integerValue != OpenedVideoPlay) {
                 [self.synchronizer closeSynchronizer];  //界面初始化失败或关闭了，则关闭同步资源
                 return ;
             }
             
             /*
              是否自动开始播放
              */
             !self.autoStart ? : [self.audioPlay startAudio:Audio_Play_Type filePath:nil];
         }];
    }
    return self;
}

- (void)setParentView:(UIView *)parentView{
    [self pauseAVPlay];
    [_videoPlay setParentView:parentView];
}

- (void)restartAVPlay{
    [self closeAVPlay];
    [self openAVPlay];
}

- (void)openAVPlay{
    [_synchronizer openSynchronizer];
}

- (void)resumeAVPlay{
    /*
     只有同步器已打开或暂停状态才可以开始
     */
    if (_synchronizer.status == DecoderOpened || _synchronizer.status == DecoderPause) {
        [_audioPlay startAudio:Audio_Play_Type filePath:nil];
        self.autoStart = YES;
    }
}

- (void)pauseAVPlay{
    /*
     只有同步器已开始状态才可以暂停
     */
    if (_synchronizer.status == DecoderDecoding) {
        [_audioPlay pauseAudioPaly];
        [_synchronizer pauseSynchronizer];
    }
}

- (void)closeAVPlay{
    [_audioPlay closeAudioPaly];
    [_videoPlay closeVideoPlay];
    [_synchronizer closeSynchronizer];
    NSLog(@"Close PlayController success!");
}

- (void)setAutoStart:(BOOL)autoStart{
    _autoStart = autoStart;
}

#pragma mark - SynchronizerDelegate

- (void)statusCallBack:(DecoderStatus)status{
    NSInteger tempStatus = status;
    ![self.delegate respondsToSelector:@selector(statusCallBack:)] ? : [self.delegate statusCallBack:tempStatus];
}

- (void)completePlayVideoFrame{
    [self closeAVPlay];
}

- (void)newCorrectVideoFrame:(Video_Frame *)videoFrame{
    [_videoPlay startRender:videoFrame width:videoFrame.width height:videoFrame.height];
}

/*
 处理第一帧视频
 */
- (void)firstCorrectVideoFrame:(Video_Frame *)videoFrame{
    [_videoPlay restartRender:videoFrame width:videoFrame.width height:videoFrame.height];
}

- (void)firstCorrectAudioFrame:(Audio_Frame *)audioFrame{
    [_audioPlay setChannel:audioFrame.channels sampleRate:audioFrame.nbSamples sampleFormat:audioFrame.sampleFormat];
}

#pragma mark - AudioRenderProtocol

- (void)retrieveCallback:(SInt16 * _Nullable)ioData numberFrames:(UInt32)numberFrames numberChannels:(UInt32)numberChannels{
    //首先判断文件是否已读取完毕
    [_synchronizer retrieveCallback:ioData numberFrames:numberFrames numberChannels:numberChannels];
}

#pragma mark - Notification

- (void)applicationWillResignActive:(NSNotification *)notification{
    [self pauseAVPlay];
}

- (void)applicationDidBecomeActive:(NSNotification *)notification{
    [self resumeAVPlay];
}

@end
