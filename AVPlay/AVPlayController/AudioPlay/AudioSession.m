//
//  AudioSessionManager.m
//  Audio and Video Play
//
//  Created by kakiYen on 2019/8/26.
//  Copyright © 2019 kakiYen. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import "AudioSession.h"

@interface AudioSession ()
@property (nonatomic) NSTimeInterval bufferDuration;
@property (nonatomic) NSString *category;
@property (nonatomic) double sampleRate;

@end

@implementation AudioSession

+ (instancetype)shareInstance{
    static dispatch_once_t dispatchOnce;
    static AudioSession *manager = nil;
    if (!manager) {
        dispatch_once(&dispatchOnce, ^{
            manager = [[AudioSession alloc] init];
        });
    }
    return manager;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _sampleRate = 44100.f;
        _bufferDuration = .002f;
        
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(interruptionNotification:) name:AVAudioSessionInterruptionNotification object:nil];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(routeChangeNotification:) name:AVAudioSessionRouteChangeNotification object:nil];
    }
    return self;
}

/*
 会话中断通知：
    AVAudioSessionCategoryPlayback
    AVAudioSessionCategoryPlayAndRecord
    AVAudioSessionCategorySoloAmbient
    AVAudioSessionCategoryMultiRoute
 */
- (void)interruptionNotification:(NSNotification *)notification{
    
}

/*
 路由变化通知，比如：连接或断开蓝牙耳机。
 */
- (void)routeChangeNotification:(NSNotification *)notification{
    NSLog(@"routeChangeNotification");
}

- (void)dealRouteChange:(AudioPlayType)playType{
    switch (playType) {
        case Audio_Record_Type:
            if (self.userSpeaker) {
                NSError *error = nil;
                [AVAudioSession.sharedInstance overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:&error] ? : NSLog(@"Occur an error when override output Audio with %@",error.domain);
            }
            break;
        default:
            break;
    }
}

//使用设备的麦克风和扬声器
- (BOOL)userMicrophone{
    NSArray *inputPort = @[AVAudioSessionPortLineIn, AVAudioSessionPortBuiltInMic];
    
    __block BOOL should = NO;
    AVAudioSessionRouteDescription *audioSessionRD = AVAudioSession.sharedInstance.currentRoute;
    [audioSessionRD.inputs enumerateObjectsUsingBlock:^(AVAudioSessionPortDescription * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([inputPort containsObject:obj.portType]) {
            should = YES;
            *stop = YES;
        }
    }];
    
    return should;
}

- (BOOL)userSpeaker{
    NSArray *outputPort = @[AVAudioSessionPortLineOut, AVAudioSessionPortBuiltInSpeaker, AVAudioSessionPortBuiltInReceiver];
    
    __block BOOL should = NO;
    AVAudioSessionRouteDescription *audioSessionRD = AVAudioSession.sharedInstance.currentRoute;
    [audioSessionRD.outputs enumerateObjectsUsingBlock:^(AVAudioSessionPortDescription * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([outputPort containsObject:obj.portType]) {
            should = YES;
            *stop = YES;
        }
    }];
    
    return should;
}


/*
 设置音频会话类型，定义怎样去使用这个音频
 */
- (void)setCategory:(NSString *)category{
    _category = category;
    
    NSError *error = nil;
    [AVAudioSession.sharedInstance setCategory:_category error:&error] ? : NSLog(@"Occur an error with %@ when setting category on audio session",error.domain);
}

/*
 设置音频每次获取输入流的时间间隔，相当于音频采样周期、或播放周期
 */
- (void)setBufferDuration:(NSTimeInterval)bufferDuration{
    _bufferDuration = bufferDuration;
    
    NSError *error = nil;
    [AVAudioSession.sharedInstance setPreferredIOBufferDuration:_bufferDuration error:&error] ? : NSLog(@"Occur an error with %@ when setting bufferDuration on audio session",error.domain);
}

/*
 设置采样率
 */
- (void)setSampleRate:(double)sampleRate{
    _sampleRate = sampleRate;
    NSError *error = nil;
    [AVAudioSession.sharedInstance setPreferredSampleRate:_sampleRate error:&error] ? : NSLog(@"Occur an error with %@ when setting sampleRate on audio session",error.domain);
}

- (void)setActive:(BOOL)active{
    [self setCategory:_category];
    [self setSampleRate:_sampleRate];
    [self setBufferDuration:_bufferDuration];
    
    NSError *error = nil;
    [AVAudioSession.sharedInstance setActive:active error:&error] ? : NSLog(@"Occur an error with %@ when active audio session",error.domain);
}

@end
