//
//  CompressionFrameRender.m
//  AVPlay
//
//  Created by kakiYen on 2019/11/25.
//  Copyright © 2019 kakiYen. All rights reserved.
//

#import "CompressionFrameRender.h"
#import "CommonGLContext.h"

@interface CompressionFrameRender (){
    CVImageBufferRef _imageBufferRef;
    CVOpenGLESTextureRef _textureRef;
    CVOpenGLESTextureCacheRef _textureCacheRef;
}
@property (weak, nonatomic) id<VideoCompressionDelegate> delegate;
@property (strong, nonatomic) dispatch_semaphore_t semaphore;
@property (strong, nonatomic) dispatch_queue_t dispatchQueue;
@property (strong, nonatomic) EAGLContext *glContext;
@property (nonatomic) GLuint outTexturesHandle;
@property (nonatomic) GLuint programHandle;
@property (nonatomic) GLuint framebuffer;
@property (nonatomic) size_t height;
@property (nonatomic) size_t width;

@end

@implementation CompressionFrameRender

- (void)dealloc{
    NSLog(@"%s",__FUNCTION__);
}

- (void)destroyRender
{
    dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
    CFRelease(_textureRef);
    CFRelease(_textureCacheRef);
    CVPixelBufferRelease(_imageBufferRef);
    glBindTexture(GL_TEXTURE_2D, 0);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glDeleteProgram(_programHandle);
    glDeleteTextures(1, &_outTexturesHandle);
    glDeleteFramebuffers(1, &_framebuffer);
    [EAGLContext setCurrentContext:nil];
    [_glContext renderbufferStorage:GL_RENDERBUFFER fromDrawable:nil];
    dispatch_semaphore_signal(self.semaphore);
    
    _success = NO;
    _textureRef = NULL;
    _framebuffer = 0;
    _programHandle = 0;
    _textureCacheRef = NULL;
    _outTexturesHandle = 0;
    
    NSLog(@"%s",__FUNCTION__);
}

- (instancetype)initWith:(size_t)width height:(size_t)height delegate:(id<VideoCompressionDelegate>)delegate
{
    self = [super init];
    if (self) {
        _width = width;
        _height = height;
        _delegate = delegate;
        _semaphore = dispatch_semaphore_create(1);
        _glContext = CommonGLContext.shareInstance.createEAGLContext;
        _dispatchQueue = dispatch_queue_create("Compression.Queue", NULL);
        
        [self initialRender];
    }
    return self;
}

- (void)initialRender{
    if (!self.setCurrentContext) {
        NSLog(@"Set Current Context Fail in Compression Frame Render!");
        return;
    }
    
    CVReturn cvReturn = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, _glContext, NULL, &_textureCacheRef);
    if (cvReturn != kCVReturnSuccess) {
        NSLog(@"Occur an error while Create Preview Texture Cache : %d",cvReturn);
        return;
    }
    
    glGenFramebuffers(1, &_framebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer); //绑定当前缓冲区
    
    _outTexturesHandle = [CommonGLContext textureCacheCVOpenGLES:&_textureRef textureCacheRef:&_textureCacheRef imageBufferRef:&_imageBufferRef internalFormat:GL_RGBA width:(GLsizei)_width height:(GLsizei)_height format:GL_BGRA planeIndex:0];
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _outTexturesHandle, 0);
    
    _success = CheckFramebufferStatus();
    if (!_success) {
        NSLog(@"Initial CameraFrameRender Fail!");
        return;
    }
    
    GLuint vertexHandle = CompileShader(self.vertexShader, GL_VERTEX_SHADER);
    GLuint fragmentHandle = CompileShader(self.fragmentSwizzlingShader, GL_FRAGMENT_SHADER);
    _programHandle = CompileProgram(vertexHandle, fragmentHandle);
    
    if (!_programHandle) {
        NSLog(@"Complie DisplayFrameRender Fail!");
        [self destroyRender];
        return;
    }
    
    _success = YES;
    glBindTexture(GL_TEXTURE_2D, 0);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
}

- (void)renderFrame:(GLuint)inTexturesHandle timingInfo:(CMSampleTimingInfo)timingInfo{
    dispatch_async(_dispatchQueue, ^{
        dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
        
        if (!self.setCurrentContext) {
            NSLog(@"Set Current Context Fail in Compression Frame Render!");
            dispatch_semaphore_signal(self.semaphore);
            return;
        }
        
        if (!self.success) {
            dispatch_semaphore_signal(self.semaphore);
            return;
        }
        
        [self startRender:inTexturesHandle timingInfo:timingInfo];
        dispatch_semaphore_signal(self.semaphore);
    });
}

- (void)startRender:(GLuint)inTexturesHandle timingInfo:(CMSampleTimingInfo)timingInfo{
    glViewport(0, 0, (GLsizei)_width, (GLsizei)_height);  //视图窗口的位置
    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
    glUseProgram(_programHandle);
    
    GLfloat imageVertex[] = {
        -1.f,-1.f,
        1.f,-1.f,
        -1.f,1.f,
        1.f,1.f,
    };
    
    int vertexPosition = glGetAttribLocation(_programHandle, "vertexPosition");
    glVertexAttribPointer(vertexPosition, 2, GL_FLOAT, GL_FALSE, 0, imageVertex);
    glEnableVertexAttribArray(vertexPosition);
    
    GLfloat texturesVertex[] = {
        0.f, 1.f,
        1.f, 1.f,
        0.f, 0.f,
        1.f, 0.f,
    };
    int textCoordinate = glGetAttribLocation(_programHandle, "textCoordinate");
    glVertexAttribPointer(textCoordinate, 2, GL_FLOAT, GL_FALSE, 0, texturesVertex);
    glEnableVertexAttribArray(textCoordinate);
    
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, inTexturesHandle);  //指定要操作的纹理
    int texSampler = glGetUniformLocation(_programHandle, "texSampler");
    glUniform1i(texSampler, 0);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    glFinish(); //等待纹理渲染完毕
    glBindTexture(GL_TEXTURE_2D, 0);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    
    CVReturn cvReturn = CVPixelBufferLockBaseAddress(_imageBufferRef, 0);
    if (cvReturn != kCVReturnSuccess) {
        NSLog(@"Lock Base Address Fail! %d",cvReturn);
        return;
    }
    
    CMSampleBufferRef sampleBufferOut;
    CMVideoFormatDescriptionRef formatDescriptionOut;
    VerifyStatus(CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, _imageBufferRef, &formatDescriptionOut), @"Fail to Create Format Description!", NO);
    VerifyStatus(CMSampleBufferCreateReadyWithImageBuffer(kCFAllocatorDefault, _imageBufferRef, formatDescriptionOut, &timingInfo, &sampleBufferOut), @"Fail to Create Sample Buffer!", NO);
    
    ![_delegate respondsToSelector:@selector(finishConvertToSampleBuffer:)] ? : [_delegate finishConvertToSampleBuffer:sampleBufferOut];
    
    cvReturn = CVPixelBufferUnlockBaseAddress(_imageBufferRef, 0);
    if (cvReturn != kCVReturnSuccess) {
        NSLog(@"UnLock Base Address Fail! %d",cvReturn);
    }
}

- (BOOL)setCurrentContext{
    BOOL should = YES;
    if (![EAGLContext.currentContext isEqual:_glContext]) {
        should = [EAGLContext setCurrentContext:_glContext];
    }
    return should;
}

- (NSString *)vertexShader{
    return GLSL_To_String
    (
        attribute vec4 vertexPosition;  //顶点坐标
        attribute vec2 textCoordinate;  //预设纹理坐标
        varying vec2 v_textCoordinate;  //传递纹理坐标
        void main(void){
            gl_Position = vertexPosition;
            v_textCoordinate = textCoordinate;
        }
     );
}

//使用OpenGL ES生成的纹理情况
- (NSString *)fragmentShader{
    return GLSL_To_String
    (
        varying highp vec2 v_textCoordinate;  //接收纹理坐标
        uniform sampler2D texSampler;  //预设纹理坐标
        void main(void){
            gl_FragColor = texture2D(texSampler, v_textCoordinate);
        }
     );
}

//使用CVOpenGL ES生产的纹理情况
- (NSString *)fragmentSwizzlingShader{
    return GLSL_To_String
    (
        varying highp vec2 v_textCoordinate;  //接收纹理坐标
        uniform sampler2D texSampler;  //预设纹理坐标
        void main(void){
            gl_FragColor = texture2D(texSampler, v_textCoordinate).bgra;
        }
     );
}

@end
