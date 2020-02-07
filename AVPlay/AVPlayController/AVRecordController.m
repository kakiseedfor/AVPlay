//
//  RecordController.m
//  AVPlay
//
//  Created by kakiYen on 2019/11/11.
//  Copyright © 2019 kakiYen. All rights reserved.
//

#import "AVRecordController.h"
#import "CameraSession.h"
#import "VideoPreview.h"
#import "AudioPlay.h"

@interface AVRecordController ()<CameraSessionDelegate>
@property (weak, nonatomic) UIView *parentView;
@property (strong, nonatomic) CameraSession *cameraSession;
@property (strong, nonatomic) VideoPreview *videoPreview;
@property (strong, nonatomic) AudioPlay *audioPlay;
@property (nonatomic) AVRecordStatus status;

@end

@implementation AVRecordController

-(void)dealloc{
    [self closeRecord];
    NSLog(@"%s",__FUNCTION__);
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _cameraSession = [[CameraSession alloc] initWith:self];
        _videoPreview = [[VideoPreview alloc] init];
        _audioPlay = [[AudioPlay alloc] init];
        _status = AVRecordUnOpen;
        
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(applicationWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
        
        @weakify(self)
        [_videoPreview addObserver:self forKeyPath:@"previewStatus" kvoCallBack:^(NSNumber * _Nullable context, NSKeyValueChange valueChange, NSIndexSet * _Nullable indexes)
         {
             @strongify(self)
             switch (context.integerValue) {
                 case UnOpenVideoPreview:
                 case ClosedVideoPreview:
                     [self.cameraSession closeCaptureSession];
                     break;
                 case OpenedVideoPreview:
                     [self startRecord];
                     break;
                 default:
                     break;
             }
         }];
    }
    return self;
}

- (instancetype)initWith:(UIView *)parentView
{
    self = [self init];
    if (self) {
        [self setParentView:parentView];
    }
    return self;
}

- (void)setParentView:(UIView *)parentView{
    _parentView = parentView;
    [self stopRecord];
    [_videoPreview setParentView:parentView];
}

- (void)setOpenRecord:(BOOL)openRecord{
//    [_videoPreview setOpenRecord:openRecord];
    [_audioPlay restartAudioEncode:BundleWithPathInResource(@"vocal.pcm")];
}

- (void)closeRecord{
    [_audioPlay closeAudioPaly];
    [_videoPreview closeVideoPreview];
    [_cameraSession closeCaptureSession];
}

- (void)startRecord{
    [_cameraSession startCaptureSession];
}

- (void)stopRecord{
    [_cameraSession stopCaptureSession];
}

#pragma mark - CameraSessionDelegate

- (void)didOutputSampleBuffer:(CVImageBufferRef)imageBufferRef timingInfo:(CMSampleTimingInfo)timingInfo{
    [_videoPreview startRender:imageBufferRef timingInfo:timingInfo isfrontCamera:_cameraSession.isfrontCamera isFullRange:_cameraSession.isFullRange];
}

- (void)didOutputFirstSampleBuffer:(CVImageBufferRef _Nullable )imageBufferRef timingInfo:(CMSampleTimingInfo)timingInfo{
    [_videoPreview restartRender:imageBufferRef timingInfo:timingInfo isfrontCamera:_cameraSession.isfrontCamera isFullRange:_cameraSession.isFullRange];
}

#pragma mark - Notification

- (void)applicationWillResignActive:(NSNotification *)notification{
    [self stopRecord];
}

- (void)applicationDidBecomeActive:(NSNotification *)notification{
    [self startRecord];
}

@end
