//
//  CameraController.h
//  AVPlay
//
//  Created by kakiYen on 2019/11/11.
//  Copyright © 2019 kakiYen. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

@protocol CameraSessionDelegate <NSObject>

- (void)didOutputSampleBuffer:(CVImageBufferRef _Nullable )imageBufferRef timingInfo:(CMSampleTimingInfo)timingInfo;

- (void)didOutputFirstSampleBuffer:(CVImageBufferRef _Nullable )imageBufferRef timingInfo:(CMSampleTimingInfo)timingInfo;

@end

NS_ASSUME_NONNULL_BEGIN

@interface CameraSession : NSObject
@property (readonly, nonatomic) BOOL isfrontCamera;
@property (readonly, nonatomic) BOOL isFullRange;

- (instancetype)initWith:(id<CameraSessionDelegate>)delegate;

- (void)closeCaptureSession;

- (void)startCaptureSession;

- (void)stopCaptureSession;

@end

NS_ASSUME_NONNULL_END
