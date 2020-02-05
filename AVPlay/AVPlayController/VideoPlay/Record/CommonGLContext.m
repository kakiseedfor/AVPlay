//
//  CommonGLContext.m
//  AVPlay
//
//  Created by kakiYen on 2019/11/13.
//  Copyright © 2019 kakiYen. All rights reserved.
//

#import "CommonGLContext.h"

@interface CommonGLContext ()
@property (strong, nonatomic) EAGLSharegroup *glSharegroup;

@end

@implementation CommonGLContext

- (void)dealloc
{
    NSLog(@"%s",__FUNCTION__);
}

+ (instancetype)shareInstance{
    static dispatch_once_t dispatchOnce;
    static CommonGLContext *glContext = nil;
    dispatch_once(&dispatchOnce, ^{
        glContext = [[CommonGLContext alloc] init];
    });
    return glContext;
}

+ (GLuint)textureCacheCVOpenGLES:(CVOpenGLESTextureRef *)textureRef
                 textureCacheRef:(CVOpenGLESTextureCacheRef *)textureCacheRef
                  imageBufferRef:(CVImageBufferRef *)imageBufferRef
                  internalFormat:(GLint)internalFormat
                           width:(GLsizei)width
                          height:(GLsizei)height
                          format:(GLenum)format
                      planeIndex:(size_t)planeIndex
{
    GLuint texturesHandle = 0;
    
    if (*textureCacheRef != NULL) {
        CVReturn cvReturn;
        if (*imageBufferRef == NULL) {
            /*
             The IOSurface framework provides a framebuffer object suitable for sharing across process boundaries. It is commonly used to allow applications to move complex image decompression and draw logic into a separate process to enhance security.
             IOSurface framework提供一个适用于共享夸线程边界的帧缓存对象。通常用来允许应用移动复杂的图片压缩，和在分离的线程中绘制逻辑来提高安全。
             就是说 要想采样会话和编码会话之间要共享CVPixelBuffer，需要设置这个属性(个人猜想，是个坑)
             */
            NSDictionary *temDic = @{(__bridge NSString *)kCVPixelBufferIOSurfacePropertiesKey : @{}};
            cvReturn = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, (__bridge CFDictionaryRef)temDic, imageBufferRef);
            
            if (cvReturn != kCVReturnSuccess) {
                NSLog(@"Occur an error while Create PixelBuffer : %d",cvReturn);
                goto retunBack;
            }
        }
        
        /*
         CVOpenGLESTextureRef texture object mapped to the CVImageBufferRef and associated parameters. This operation creates a live binding between the image buffer and the underlying texture object.
         CVOpenGLESTextureRef texture object 会映射到 CVImageBufferRef 和 关联的参数中。
         这个操作将会创建一个 image buffer采样缓冲区与 texture object纹理对象 之间的持续性的绑定
         */
        
        /*
         创建纹理缓存大小规格需根据采样帧的大小设置。
         */
        cvReturn = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                                *textureCacheRef,
                                                                *imageBufferRef,
                                                                NULL,
                                                                GL_TEXTURE_2D,
                                                                internalFormat,    //渲染到纹理的格式
                                                                width, height,
                                                                format,    //这里创建时是指定kCVPixelFormatType_32BGRA
                                                                GL_UNSIGNED_BYTE,
                                                                planeIndex, textureRef);
        
        if (cvReturn != kCVReturnSuccess) {
            NSLog(@"Occur an error while Cache Create Texture : %d",cvReturn);
            goto retunBack;
        }
        
        texturesHandle = CVOpenGLESTextureGetName(*textureRef);
        glBindTexture(CVOpenGLESTextureGetTarget(*textureRef), texturesHandle);
    }else{
        glGenTextures(1, &texturesHandle);
        glBindTexture(GL_TEXTURE_2D, texturesHandle);
        glTexImage2D(GL_TEXTURE_2D, 0, internalFormat, (GLuint)width, (GLuint)height, 0, format, GL_UNSIGNED_BYTE, NULL);
    }
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);   //放大处理方式
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);   //缩小处理方式
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
retunBack:
    return texturesHandle;
}

- (EAGLContext *)createEAGLContext{
    /*
     也是个坑，之前以为_glSharegroup会被自动赋值，导致不同的OpenGL ES上下文环境里的纹理不能共享。
     */
    EAGLContext *glContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2 sharegroup:_glSharegroup];
    if (!_glSharegroup) {
        _glSharegroup = glContext.sharegroup;
    }
    return glContext;
}

- (void)destroyCommonGLContext{
    _glSharegroup = nil;
    
}

@end
