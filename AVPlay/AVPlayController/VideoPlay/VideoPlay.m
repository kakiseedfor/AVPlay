//
//  PngPreview.m
//  Audio and Video Play
//
//  Created by kakiYen on 2019/8/20.
//  Copyright © 2019 kakiYen. All rights reserved.
//

#import "DisplayFrameRender.h"
#import "FilterFrameRender.h"
#import "YUVFrameRender.h"
#import "VideoPlay.h"

@interface VideoPlay ()
@property (strong, nonatomic) dispatch_semaphore_t semaphore;
@property (strong, nonatomic) dispatch_queue_t dispatchQueue;
@property (strong, nonatomic) DisplayFrameRender *displayFrameRender;
@property (strong, nonatomic) FilterFrameRender *filterFrameRender;
@property (strong, nonatomic) YUVFrameRender *yuvFrameRender;
@property (strong, nonatomic) Video_Frame *videoFrame;
@property (strong, nonatomic) EAGLContext *glContext;
@property (nonatomic) VideoPlayStatus status;
@property (nonatomic) CGFloat aspectRatio;
@property (nonatomic) int pixelHeight;
@property (nonatomic) int pixelWidth;

@end

@implementation VideoPlay

- (void)dealloc
{
    NSLog(@"%s",__FUNCTION__);
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _status = UnOpenVideoPlay;
        _semaphore = dispatch_semaphore_create(1);
        _glContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        _dispatchQueue = dispatch_queue_create("VideoPlay.Queue", NULL);
        
        CAEAGLLayer *layer = (CAEAGLLayer *)self.layer;
        layer.drawableProperties = @{kEAGLDrawablePropertyColorFormat : kEAGLColorFormatRGBA8,
                                     kEAGLDrawablePropertyRetainedBacking : @(NO)};
        layer.opaque = YES;
    }
    return self;
}

- (void)closeVideoPlay{
    if (_status != OpenedVideoPlay) {
        return;
    }
    
    _status = ClosedVideoPlay;
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    
    [EAGLContext setCurrentContext:nil];
    [_yuvFrameRender destroyRender];
    [_filterFrameRender destroyRender];
    [_displayFrameRender destroyRender];
    [_glContext renderbufferStorage:GL_RENDERBUFFER fromDrawable:nil];
    dispatch_semaphore_signal(_semaphore);
    
    NSLog(@"Close VideoPaly success!");
}

- (void)openVideoPlay:(int)pixelWidth height:(int)pixelHeight{
    self.pixelWidth = pixelWidth;
    self.pixelHeight = pixelHeight;
    
    __block CAEAGLLayer *layer = nil;
    dispatch_sync(dispatch_get_main_queue(), ^{
        if (!self.superview) {
            NSLog(@"Could not open VideoPlay until you have added a parent View to it!");
            self.status = ClosedVideoPlay;
            return;
        }
        
        CGRect rect = CGRectZero;
        CGFloat aspectRatio = 0.f;
        FitSizeToView(self.superview.bounds, CGSizeMake(self.pixelWidth, self.pixelHeight), &rect, &aspectRatio);
        self.layer.frame = rect;
        self.aspectRatio = aspectRatio;
        layer = (CAEAGLLayer *)self.layer;
    });
    
    if (self.status == ClosedVideoPlay) {
        return;
    }
    
    if (!_displayFrameRender.success) {
        _displayFrameRender = [[DisplayFrameRender alloc] initWith:layer glContext:_glContext];
    }
    
    if (!_yuvFrameRender.success) {
        _yuvFrameRender = [[YUVFrameRender alloc] initWith:_displayFrameRender.width height:_displayFrameRender.height];
    }
    
    if (!_filterFrameRender.success) {
        _filterFrameRender = [[FilterFrameRender alloc] initWith:_displayFrameRender.width height:_displayFrameRender.height];
    }
    
    if (!_displayFrameRender.success || !_yuvFrameRender.success || !_filterFrameRender.success) {
        self.status = ClosedVideoPlay;
        return;
    }
    
    self.status = OpenedVideoPlay;
}

- (void)reStartRender:(Video_Frame *)videoFrame width:(int)pixelWidth height:(int)pixelHeight{
    _status = UnOpenVideoPlay;
    [self startRender:videoFrame width:pixelWidth height:pixelHeight];
}

- (void)startRender:(Video_Frame *)videoFrame width:(int)pixelWidth height:(int)pixelHeight{
    if (_status == ClosedVideoPlay) {
        return;
    }
    
    @weakify(self)   //与StrongSelf配合防止线程资源被其他现场释放
    !videoFrame ? : dispatch_async(_dispatchQueue, ^{
        @strongify(self)
        
        dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
        
        /*
         You should avoid making the same context current on multiple threads. OpenGL ES provides no thread safety, so if you want to use the same context on multiple threads, you must employ some form of thread synchronization to prevent simultaneous access to the same context from multiple threads.
         一个EAGLContext上下文的使用尽量在同一个线程上，因为OpenGL ES是线程不安全。可以避免未知错误
         */
        if (!self.setCurrentContext) {
            NSLog(@"Set Current Context Fail when set parentView!");
            dispatch_semaphore_signal(self.semaphore);
            return;
        }
        
        switch (self.status) {
            case UnOpenVideoPlay:
                [self openVideoPlay:pixelWidth height:pixelHeight];
                break;
            case ClosedVideoPlay:{
                dispatch_semaphore_signal(self.semaphore);
                return;
            }
                break;
            default:
                break;
        }
        
        if (!self || self.status != OpenedVideoPlay) {
            glFinish(); //提交GLSL
            dispatch_semaphore_signal(self.semaphore);
            return ;
        }
        
        self.videoFrame = videoFrame;
        [self.yuvFrameRender renderFrame:self.videoFrame];
        [self.filterFrameRender renderFrame:self.yuvFrameRender.getTexturesHandle];
        [self.displayFrameRender renderFrame:self.filterFrameRender.getTexturesHandle aspectRatio:self.aspectRatio];
        [self.glContext presentRenderbuffer:GL_RENDERBUFFER];
        
        dispatch_semaphore_signal(self.semaphore);
    });
}

- (void)setParentView:(UIView *)parentView{
    if (!self.setCurrentContext) {
        NSLog(@"Set Current Context Fail when set parentView!");
        return;
    }
    
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    [_displayFrameRender destroyRender];
    dispatch_semaphore_signal(_semaphore);
    
    [self removeFromSuperview];
    [parentView addSubview:self];
    [self reStartRender:self.videoFrame width:_pixelWidth height:_pixelHeight];
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
