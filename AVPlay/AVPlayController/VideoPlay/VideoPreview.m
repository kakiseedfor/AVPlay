//
//  VideoPreview.m
//  AVPlay
//
//  Created by kakiYen on 2019/11/11.
//  Copyright © 2019 kakiYen. All rights reserved.
//

#import "CompressionFrameRender.h"
#import "DisplayFrameRender.h"
#import "CameraFrameRender.h"
#import "FilterFrameRender.h"
#import "CommonGLContext.h"
#import "VTEncodeSession.h"
#import "VideoPreview.h"

@interface VideoPreview ()<VideoCompressionDelegate>{
    CVImageBufferRef _copyImageBufferRef;
}
@property (strong, nonatomic) CompressionFrameRender *compressionFrameRender;
@property (strong, nonatomic) DisplayFrameRender *displayFrameRender;
@property (strong, nonatomic) FilterFrameRender *filterFrameRender;
@property (strong, nonatomic) CameraFrameRender *cameraFrameRender;
@property (strong, nonatomic) VTEncodeSession *encodeSession;
@property (strong, nonatomic) dispatch_semaphore_t semaphore;
@property (strong, nonatomic) dispatch_queue_t dispatchQueue;
@property (strong, nonatomic) EAGLContext *glContext;
@property (nonatomic) VideoPreviewStatus previewStatus;
@property (nonatomic) VideoRecordStatus recordStatus;
@property (nonatomic) CGFloat aspectRatio;
@property (nonatomic) BOOL isfrontCamera;
@property (nonatomic) BOOL isFullRange;
@property (nonatomic) size_t pixelHeight;
@property (nonatomic) size_t pixelWidth;

@end

@implementation VideoPreview

- (void)dealloc
{
    [self closeVideoPreview];
    NSLog(@"%s",__FUNCTION__);
}

- (void)closeVideoPreview{
    if (_previewStatus != OpenedVideoPreview) {
        return;
    }
    
    _recordStatus = ClosedVideoRecord;
    _previewStatus = ClosedVideoPreview;
    dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
    [EAGLContext setCurrentContext:nil];
    [_cameraFrameRender destroyRender];
    [_filterFrameRender destroyRender];
    [_displayFrameRender destroyRender];
    [_compressionFrameRender destroyRender];
    [_glContext renderbufferStorage:GL_RENDERBUFFER fromDrawable:nil];
    CVPixelBufferRelease(_copyImageBufferRef);
    dispatch_semaphore_signal(self.semaphore);
    
    [_encodeSession closeEncoderSession];
    
    NSLog(@"Close VideoPreview success!");
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _glContext = CommonGLContext.shareInstance.createEAGLContext;
        _semaphore = dispatch_semaphore_create(1);
        _recordStatus = ClosedVideoRecord;
        _previewStatus = UnOpenVideoPreview;
        _encodeSession = [[VTEncodeSession alloc] init];
        _dispatchQueue = dispatch_queue_create("VideoPreview.Queue", NULL);
        
        CAEAGLLayer *layer = (CAEAGLLayer *)self.layer;
        layer.drawableProperties = @{kEAGLDrawablePropertyColorFormat : kEAGLColorFormatRGBA8,
                                     kEAGLDrawablePropertyRetainedBacking : @(NO)};
        layer.opaque = YES;
    }
    return self;
}

- (void)openVideoPreview:(size_t)pixelWidth height:(size_t)pixelHeight{
    _pixelWidth = pixelWidth;
    _pixelHeight = pixelHeight;
    
    __block CAEAGLLayer *layer = nil;
    dispatch_sync(dispatch_get_main_queue(), ^{
        if (!self.superview) {
            NSLog(@"Could not open VideoPlay until you have added a parent View to it!");
            self.previewStatus = ClosedVideoPreview;
            return;
        }
        
        CGRect rect = CGRectZero;
        CGFloat aspectRatio = 0.f;
        FitSizeToView(self.superview.bounds, CGSizeMake(pixelWidth, pixelHeight), &rect, &aspectRatio);
        self.layer.frame = rect;
        self.aspectRatio = aspectRatio;
        layer = (CAEAGLLayer *)self.layer;
    });
    
    if (self.previewStatus == ClosedVideoPreview) {
        return;
    }
    
    if (!_displayFrameRender.success) {
        _displayFrameRender = [[DisplayFrameRender alloc] initWith:layer glContext:_glContext];
    }
    
    if (!_filterFrameRender.success) {
        _filterFrameRender = [[FilterFrameRender alloc] initWith:_displayFrameRender.width height:_displayFrameRender.height];
    }
    
    if (!_cameraFrameRender.success) {
        _cameraFrameRender = [[CameraFrameRender alloc] initWith:_glContext isFullRange:_isFullRange width:pixelWidth height:pixelHeight];
    }
    
    if (!_displayFrameRender.success || !_cameraFrameRender.success || !_filterFrameRender.success) {
        self.previewStatus = ClosedVideoPreview;
        return;
    }
    
    self.previewStatus = OpenedVideoPreview;
}

- (void)reStartRender:(CVImageBufferRef)imageBufferRef timingInfo:(CMSampleTimingInfo)timingInfo isfrontCamera:(BOOL)isfrontCamera isFullRange:(BOOL)isFullRange
{
    _previewStatus = UnOpenVideoPreview;
    [self startRender:imageBufferRef timingInfo:(CMSampleTimingInfo)timingInfo isfrontCamera:isfrontCamera isFullRange:isFullRange];
}

- (void)startRender:(CVImageBufferRef)imageBufferRef timingInfo:(CMSampleTimingInfo)timingInfo isfrontCamera:(BOOL)isfrontCamera isFullRange:(BOOL)isFullRange
{
    if (_previewStatus == ClosedVideoPreview) {
        return;
    }
    
    _isFullRange = isFullRange;
    _isfrontCamera = isfrontCamera;
    
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    if (_previewStatus == ClosedVideoPreview) {
        dispatch_semaphore_signal(_semaphore);
        return;
    }
    
    [self copyImageBufferRef:imageBufferRef];
    
    @weakify(self)
    !imageBufferRef ? : dispatch_async(_dispatchQueue, ^{
        @strongify(self)
        
        dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
        
        if (!self.setCurrentContext) {
            NSLog(@"Set Current Context Fail in VideoPreview!");
            dispatch_semaphore_signal(self.semaphore);
            return;
        }
        
        switch (self.previewStatus) {
            case UnOpenVideoPreview:
                [self openVideoPreview:CVPixelBufferGetWidth(self->_copyImageBufferRef) height:CVPixelBufferGetHeight(self->_copyImageBufferRef)];
                break;
            case ClosedVideoPreview:{
                dispatch_semaphore_signal(self.semaphore);
                return;
            }
                break;
            default:
                break;
        }
        
        if (!self || self.previewStatus != OpenedVideoPreview) {
            glFinish(); //提交GLSL
            CVPixelBufferRelease(self->_copyImageBufferRef);   //释放采样帧
            dispatch_semaphore_signal(self.semaphore);
            return ;
        }
        
        [self.cameraFrameRender renderFrame:self->_copyImageBufferRef];
        [self.filterFrameRender renderFrame:self.cameraFrameRender.getTexturesHandle];
        [self.displayFrameRender renderFrame:self.filterFrameRender.getTexturesHandle aspectRatio:self.aspectRatio];
        [self.glContext presentRenderbuffer:GL_RENDERBUFFER];
        
        //是否开始录制
        [self startRecord:self.cameraFrameRender.getTexturesHandle timingInfo:timingInfo];
        dispatch_semaphore_signal(self.semaphore);
    });
    dispatch_semaphore_signal(_semaphore);
}

- (void)startRecord:(GLuint)inTexturesHandle timingInfo:(CMSampleTimingInfo)timingInfo{
    //没有采样时间，则跳过编码
    if (CMTimeCompare(timingInfo.presentationTimeStamp, kCMTimeInvalid) == 0 &&
        CMTimeCompare(timingInfo.decodeTimeStamp, kCMTimeInvalid) == 0 &&
        CMTimeCompare(timingInfo.duration, kCMTimeInvalid) == 0) {
        return;
    }
    
    switch (_recordStatus) {
        case OpenVideoRecord:{
            if (!_compressionFrameRender.success) {
                _compressionFrameRender = [[CompressionFrameRender alloc] initWith:_pixelWidth height:_pixelHeight delegate:self];
            }
            
            if (!_compressionFrameRender.success) {
                _recordStatus = ClosedVideoRecord;
                [_encodeSession closeEncoderSession];
                break;
            }
            
            _recordStatus = OpenedVideoRecord;
        }
        case OpenedVideoRecord:{
            if (!_compressionFrameRender.success) {
                _recordStatus = ClosedVideoRecord;
                break;
            }
            
            [_compressionFrameRender renderFrame:inTexturesHandle timingInfo:timingInfo];
        }
            break;
        case ClosedVideoRecord:
            [_encodeSession closeEncoderSession];
            break;
        default:
            break;
    }
}

- (void)finishConvertToSampleBuffer:(CMSampleBufferRef)sampleBuffer{
    [_encodeSession startEncoderSession:sampleBuffer];
}

- (void)copyImageBufferRef:(CVPixelBufferRef)imageBufferRef{
    if (!imageBufferRef) {
        return;
    }
    
    if (!_copyImageBufferRef) {
        CVReturn cvReturn = CVPixelBufferCreate(kCFAllocatorDefault, CVPixelBufferGetWidth(imageBufferRef), CVPixelBufferGetHeight(imageBufferRef), CVPixelBufferGetPixelFormatType(imageBufferRef), NULL, &_copyImageBufferRef);
        
        if (cvReturn != kCVReturnSuccess) {
            NSLog(@"Create buffer pixel fail! %d",cvReturn);
            return;
        }
    }
    CVBufferPropagateAttachments(imageBufferRef, _copyImageBufferRef);
    
    CVReturn cvReturn = CVPixelBufferLockBaseAddress(imageBufferRef, kCVPixelBufferLock_ReadOnly);
    if (cvReturn != kCVReturnSuccess) {
        NSLog(@"Lock Base Address Fail! %d",cvReturn);
        return;
    }
    cvReturn = CVPixelBufferLockBaseAddress(_copyImageBufferRef, 0);
    if (cvReturn != kCVReturnSuccess) {
        NSLog(@"Lock Base Address Fail! %d",cvReturn);
        return;
    }
    
    for (size_t i = 0; i < CVPixelBufferGetPlaneCount(imageBufferRef); i++) {
        void *copyPlane = CVPixelBufferGetBaseAddressOfPlane(_copyImageBufferRef, i);
        void *plane = CVPixelBufferGetBaseAddressOfPlane(imageBufferRef, i);
        size_t height = CVPixelBufferGetHeightOfPlane(imageBufferRef, i);
        size_t row = CVPixelBufferGetBytesPerRowOfPlane(imageBufferRef, i);
        memcpy(copyPlane, plane, row * height);
    }
    
    cvReturn = CVPixelBufferUnlockBaseAddress(_copyImageBufferRef, 0);
    if (cvReturn != kCVReturnSuccess) {
        NSLog(@"UnLock Base Address Fail! %d",cvReturn);
        return;
    }
    
    cvReturn = CVPixelBufferUnlockBaseAddress(imageBufferRef, kCVPixelBufferLock_ReadOnly);
    if (cvReturn != kCVReturnSuccess) {
        NSLog(@"UnLock Base Address Fail! %d",cvReturn);
        return;
    }
}

- (void)setParentView:(UIView *)parentView{
    if (!self.setCurrentContext) {
        NSLog(@"Set Current Context Fail when set parentView!");
        return;
    }
    [_displayFrameRender destroyRender];
    
    [self removeFromSuperview];
    [parentView addSubview:self];
    [self reStartRender:_copyImageBufferRef timingInfo:kCMTimingInfoInvalid isfrontCamera:_isfrontCamera isFullRange:_isFullRange];
}

- (void)setOpenRecord:(BOOL)openRecord{
    _recordStatus = openRecord ? OpenVideoRecord : ClosedVideoRecord;
}

- (BOOL)setCurrentContext{
    BOOL should = YES;
    if (![EAGLContext.currentContext isEqual:_glContext]) {
        should = [EAGLContext setCurrentContext:_glContext];
    }
    return should;
}

+ (Class)layerClass{
    return CAEAGLLayer.class;
}

@end
