//
//  CameraController.m
//  AVPlay
//
//  Created by kakiYen on 2019/11/11.
//  Copyright © 2019 kakiYen. All rights reserved.
//

#import "CommonUtility.h"
#import "CameraSession.h"
#import "CommonGLContext.h"

@interface CameraSession ()<AVCaptureVideoDataOutputSampleBufferDelegate>
@property (weak, nonatomic) id<CameraSessionDelegate> delegate;
@property (strong, nonatomic) AVCaptureVideoDataOutput *captureDeviceOutput;
@property (strong, nonatomic) AVCaptureDeviceInput *captureDeviceInput;
@property (strong, nonatomic) AVCaptureSession *captureSession;
@property (strong, nonatomic) dispatch_semaphore_t semaphore;
@property (strong, nonatomic) dispatch_queue_t dispatchQueue;
@property (nonatomic) BOOL openedSession;
@property (nonatomic) BOOL isfrontCamera;
@property (nonatomic) BOOL isfirstFrame;
@property (nonatomic) BOOL isFullRange;

@end

@implementation CameraSession

- (void)dealloc
{
    NSLog(@"%s",__FUNCTION__);
}

- (instancetype)initWith:(id<CameraSessionDelegate>)delegate
{
    self = [super init];
    if (self) {
        _delegate = delegate;
        _semaphore = dispatch_semaphore_create(1);
        _dispatchQueue =  dispatch_queue_create("CameraSession.dispatchQueue", DISPATCH_QUEUE_SERIAL);
        _isfirstFrame = YES;
    }
    return self;
}

#pragma mark - Init Session

- (void)closeCaptureSession{
    if (!_openedSession) {
        return;
    }
    
    _openedSession = NO;
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    [self stopCaptureSession];
    [_captureDeviceOutput setSampleBufferDelegate:nil queue:nil];
    _isfirstFrame = NO;
    
    [_captureSession beginConfiguration];
    [_captureSession removeInput:_captureDeviceInput];
    [_captureSession removeOutput:_captureDeviceOutput];
    [_captureSession commitConfiguration];
    [NSNotificationCenter.defaultCenter removeObserver:self];
    dispatch_semaphore_signal(_semaphore);
    
    NSLog(@"Close CameraSession success!");
}

- (void)startCaptureSession{
    HasAuthorization(AVMediaTypeVideo, ^(BOOL granted) {
        !granted ? : dispatch_async(self.dispatchQueue, ^{
            if (!self.openedSession) {
                [self initialCaptureSession];
            }
            
            if (!self.openedSession) {
                return;
            }
            
            self.captureSession.isRunning ? : [self.captureSession startRunning];
        });
    });
}

- (void)stopCaptureSession{
    !_captureSession.isRunning ? : [_captureSession stopRunning];
}

- (void)initialCaptureSession{
    _captureSession = [[AVCaptureSession alloc] init];
    
    AVCaptureVideoDataOutput *captureDeviceOutput = [[AVCaptureVideoDataOutput alloc] init];
    captureDeviceOutput.alwaysDiscardsLateVideoFrames = YES;   //在回调代理处理完之前，将忽略掉后面采集的画面。
    [captureDeviceOutput.availableVideoCVPixelFormatTypes enumerateObjectsUsingBlock:^(NSNumber * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        //查看支持的像素格式
        if (obj.intValue == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) {
            self.isFullRange = YES;
            *stop = YES;
        }
    }];
    
    /*
     设置对应的像素编码格式。
     后续转换纹理时，需要根据这个标志取用对应的像素格式转换矩阵。
     */
    [captureDeviceOutput setVideoSettings:@{(NSString *)kCVPixelBufferPixelFormatTypeKey : @(_isFullRange ? kCVPixelFormatType_420YpCbCr8BiPlanarFullRange : kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)}];
    [captureDeviceOutput setSampleBufferDelegate:self queue:dispatch_queue_create("Output.SampleBuffer.Delegate", DISPATCH_QUEUE_SERIAL)];
    
    if (![_captureSession canAddOutput:captureDeviceOutput]) {
        NSLog(@"Could not add out put to Capture Sessionn!");
        return;
    }
    
    [_captureSession addOutput:captureDeviceOutput];
    _captureDeviceOutput = captureDeviceOutput;
    
    [self switchCaptureSession];
    
    [_captureSession beginConfiguration];
    //设置摄像头的分辨率
    _captureSession.sessionPreset = [_captureSession canSetSessionPreset:AVCaptureSessionPreset1280x720] ? AVCaptureSessionPreset1280x720 : AVCaptureSessionPreset640x480;  //⚠️
    [_captureSession commitConfiguration];
    
    AVCaptureConnection *captureConnection = [_captureDeviceOutput connectionWithMediaType:AVMediaTypeVideo];
    captureConnection.videoOrientation = AVCaptureVideoOrientationPortrait;    //设置摄像头方向⚠️
    self.openedSession = YES;
}

- (void)switchCaptureSession{
    AVCaptureDevice *captureDevice = [self cameraWithPosition:_isfrontCamera ? AVCaptureDevicePositionFront : AVCaptureDevicePositionBack];
    
    NSError *error = nil;
    AVCaptureDeviceInput *captureDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:captureDevice error:&error];
    if (error) {
        NSLog(@"%@",error.userInfo[@"NSUnderlyingError"]);
        return;
    }
    
    if (![_captureSession canAddInput:captureDeviceInput]) {
        [_captureSession removeInput:_captureDeviceInput];
        
        if (![_captureSession canAddInput:captureDeviceInput]) {
            [_captureSession addInput:_captureDeviceInput];
            NSLog(@"Switch Capture Session Fail!");
        }
    }else{
        [_captureSession addInput:captureDeviceInput];
    }
    _captureDeviceInput = captureDeviceInput;
    
    [_captureSession beginConfiguration];
    //支持防抖
    ![captureDeviceInput.device.activeFormat isVideoStabilizationModeSupported:AVCaptureVideoStabilizationModeStandard] ? : [[_captureDeviceOutput connectionWithMediaType:AVMediaTypeVideo] setPreferredVideoStabilizationMode:AVCaptureVideoStabilizationModeStandard];
    [_captureSession commitConfiguration];
}

- (AVCaptureDevice *)cameraWithPosition:(AVCaptureDevicePosition)position{
    __block AVCaptureDevice *captureDevice = nil;
    NSArray<AVCaptureDevice *> *captureDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    [captureDevices enumerateObjectsUsingBlock:^(AVCaptureDevice * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (obj.position == position) {
            captureDevice = obj;
            
            NSError *error = nil;
            /*
             若设备支持自动聚焦，则设置自动聚焦。
             设置聚焦区域
             */
            if ([obj isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus] && [obj lockForConfiguration:&error]) {
                [obj setFocusMode:AVCaptureFocusModeContinuousAutoFocus];
                !obj.isFocusPointOfInterestSupported ? : [obj setFocusPointOfInterest:CGPointMake(.5f, .5f)];
                [obj unlockForConfiguration];
            }else{
                NSLog(@"%@",error.userInfo[@"NSUnderlyingError"]);
            }
            *stop = YES;
        }
    }];
    return captureDevice;
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    if (!_openedSession) {
        return;
    }
    
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    
    if (!_openedSession) {
        dispatch_semaphore_signal(_semaphore);
        return;
    }
    
    /*
     为防止持有sample时间过长，对sample进行拷贝
     */
    CFRetain(sampleBuffer);
    CMSampleTimingInfo timingInfo = kCMTimingInfoInvalid;
    VerifyStatus(CMSampleBufferGetSampleTimingInfo(sampleBuffer, 0, &timingInfo), @"Get Sample TimingInfo Fail!", NO);
    
    if (_isfirstFrame) {
        _isfirstFrame = NO;
        ![self.delegate respondsToSelector:@selector(didOutputFirstSampleBuffer:timingInfo:)] ? : [self.delegate didOutputFirstSampleBuffer:CMSampleBufferGetImageBuffer(sampleBuffer) timingInfo:timingInfo];
    }else{
       ![self.delegate respondsToSelector:@selector(didOutputSampleBuffer:timingInfo:)] ? : [self.delegate didOutputSampleBuffer:CMSampleBufferGetImageBuffer(sampleBuffer) timingInfo:timingInfo];
    }
    CFRelease(sampleBuffer);
    
    dispatch_semaphore_signal(_semaphore);
}

@end
