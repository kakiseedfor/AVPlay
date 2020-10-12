//
//  CameraFrameRender.m
//  AVPlay
//
//  Created by kakiYen on 2019/11/11.
//  Copyright © 2019 kakiYen. All rights reserved.
//

#import "CameraFrameRender.h"
#import "CommonGLContext.h"
#import "CommonUtility.h"

//超清电视
GLfloat ColorConversion709Default[] = {
    1.164, 1.164, 1.164,
    0.f, -0.213, 2.112,
    1.793, -0.533, 0.f,
};

//标清电视
GLfloat ColorConversion601Default[] = {
    1.164, 1.164, 1.164,
    0.f, -0.392, 2.017,
    1.596, -0.813, 0.f,
};

//标清电视 FullRange
GLfloat ColorConversion601FullRangeDefault[] = {
    1.f, 1.f, 1.f,
    0.f, -0.343, 1.765,
    1.4, -0.711, 0.f,
};

@interface CameraFrameRender (){
    CVImageBufferRef _imageBufferRef;
    CVOpenGLESTextureRef _textureRef;
    CVOpenGLESTextureRef _YtextureRef;
    CVOpenGLESTextureRef _UVtextureRef;
    CVOpenGLESTextureCacheRef _textureCacheRef;
}
@property (nonatomic) GLuint outTexturesHandle;
@property (nonatomic) GLuint programHandle;
@property (nonatomic) GLuint framebuffer;
@property (nonatomic) size_t height;
@property (nonatomic) size_t width;
@property (nonatomic) BOOL isFullRange;

@end

@implementation CameraFrameRender

- (void)dealloc
{
    NSLog(@"%s",__FUNCTION__);
}

- (void)destroyRender
{
    glBindTexture(GL_TEXTURE_2D, 0);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glDeleteProgram(_programHandle);
    glDeleteTextures(1, &_outTexturesHandle);
    glDeleteFramebuffers(1, &_framebuffer);
    CVPixelBufferRelease(_imageBufferRef);
    CFRelease(_textureCacheRef);
    CFRelease(_UVtextureRef);
    CFRelease(_YtextureRef);
    CFRelease(_textureRef);
    _textureRef = NULL;
    _YtextureRef = NULL;
    _UVtextureRef = NULL;
    _textureCacheRef = NULL;
    _success = NO;
    _framebuffer = 0;
    _programHandle = 0;
    _outTexturesHandle = 0;
    
    NSLog(@"%s",__FUNCTION__);
}

- (instancetype)initWith:(EAGLContext *)glContext isFullRange:(BOOL)isFullRange width:(size_t)width height:(size_t)height
{
    self = [super init];
    if (self) {
        _width = width;
        _height = height;
        _isFullRange = isFullRange;
        CVReturn cvReturn = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, glContext, NULL, &_textureCacheRef);
        cvReturn == kCVReturnSuccess ? : NSLog(@"Occur an error while Create Preview Texture Cache : %d",cvReturn);
        
        glGenFramebuffers(1, &_framebuffer);
        glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer); //绑定当前缓冲区
        
        /*
         输出纹理优先从Core Video硬件编码器汇总获取，或从OpenGL ES中创建
         */
        _outTexturesHandle = [CommonGLContext textureCacheCVOpenGLES:&_textureRef textureCacheRef:&_textureCacheRef imageBufferRef:&_imageBufferRef internalFormat:GL_RGBA width:(GLsizei)_width height:(GLsizei)_height format:GL_BGRA planeIndex:0];
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _outTexturesHandle, 0);
        
        _success = CheckFramebufferStatus();
        if (!_success) {
            NSLog(@"Initial CameraFrameRender Fail!");
        }
        
        GLuint vertexHandle = CompileShader(self.vertexShader, GL_VERTEX_SHADER);
        GLuint fragmentHandle = CompileShader(isFullRange ? self.fullRangeFragmentShader : self.unFullRangeFragmentShader, GL_FRAGMENT_SHADER);
        _programHandle = CompileProgram(vertexHandle, fragmentHandle);
        
        if (!_programHandle) {
            _success = NO;
            NSLog(@"Complie CameraFrameRender Fail!");
        }
        
        glBindTexture(GL_TEXTURE_2D, 0);
        glBindFramebuffer(GL_FRAMEBUFFER, 0);
    }
    return self;
}

/*
 根据撇值，CVImageBufferRef具有两个分量。[planes = 2]
 */
- (void)renderFrame:(CVImageBufferRef)cameraFrame
{
    size_t frameWidth = CVPixelBufferGetWidth(cameraFrame);
    size_t frameHeight = CVPixelBufferGetHeight(cameraFrame);
    
    CFTypeRef typeRef = CVBufferGetAttachment(cameraFrame, kCVImageBufferYCbCrMatrixKey, NULL);
    
    GLfloat *colorConvertMatrix = NULL;
    if (typeRef) {
        if (CFStringCompare(typeRef, kCVImageBufferYCbCrMatrix_ITU_R_601_4, 0) == kCFCompareEqualTo) {
            colorConvertMatrix = _isFullRange ? ColorConversion601FullRangeDefault : ColorConversion601Default;
        }else{
            colorConvertMatrix = ColorConversion709Default;
        }
    }else{
        colorConvertMatrix = _isFullRange ? ColorConversion601FullRangeDefault : ColorConversion601Default;
    }
    
    CVPixelBufferLockBaseAddress(cameraFrame, 0);
    GLuint YtextureHandle = [CommonGLContext textureCacheCVOpenGLES:&_YtextureRef textureCacheRef:&_textureCacheRef imageBufferRef:&cameraFrame internalFormat:GL_LUMINANCE width:(GLsizei)frameWidth height:(GLsizei)frameHeight format:GL_LUMINANCE planeIndex:0];
    
    /*
     U分量存储在LUMINANCE中，V分量存储在ALPHA中。
     */
    GLuint UVtextureHandle = [CommonGLContext textureCacheCVOpenGLES:&_UVtextureRef textureCacheRef:&_textureCacheRef imageBufferRef:&cameraFrame internalFormat:GL_LUMINANCE_ALPHA width:(GLsizei)frameWidth / 2 height:(GLsizei)frameHeight / 2 format:GL_LUMINANCE_ALPHA planeIndex:1];
    CVPixelBufferUnlockBaseAddress(cameraFrame, 0);
    
    /*
     特别注意：指定的视图窗口大小要与创建输出纹理相同。
     */
    glViewport(0, 0, (GLsizei)_width, (GLsizei)_height);
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
    
    int colorMatrix = glGetUniformLocation(_programHandle, "colorMatrix");
    glUniformMatrix3fv(colorMatrix, 1, GL_FALSE, colorConvertMatrix);
    
    glActiveTexture(GL_TEXTURE0);   //激活哪个纹理单元
    glBindTexture(GL_TEXTURE_2D, YtextureHandle);  //指定要操作的纹理
    int YtexSampler = glGetUniformLocation(_programHandle, "YtexSampler");    //获取 GLSL 里的 "YtexSampler" 变量
    glUniform1i(YtexSampler, 0); //将 GL_TEXTURE0 纹理单元赋值到 YtexSampler
    
    glActiveTexture(GL_TEXTURE1);   //激活哪个纹理单元
    glBindTexture(GL_TEXTURE_2D, UVtextureHandle);  //指定要操作的纹理
    int UVtexSampler = glGetUniformLocation(_programHandle, "UVtexSampler");    //获取 GLSL 里的 "UVtexSampler" 变量
    glUniform1i(UVtexSampler, 1); //将 GL_TEXTURE1 纹理单元赋值到 UVtexSampler
    
    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer); //绑定当前缓冲区
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);  //将纹理渲染到帧缓冲 Framebuffers
    glBindTexture(GL_TEXTURE_2D, 0);    //取消对 _texturesHandle 这个纹理操作
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    
//    GLenum code = glGetError();
//    NSLog(@"%s code %d",__FUNCTION__,code);
}

- (GLuint)getTexturesHandle{
    return _outTexturesHandle;
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

- (NSString *)fullRangeFragmentShader{
    return GLSL_To_String
    (
        varying highp vec2 v_textCoordinate;  //接收纹理坐标
        uniform sampler2D YtexSampler;  //预设Y纹理坐标
        uniform sampler2D UVtexSampler;  //预设UV纹理坐标
        uniform mediump mat3 colorMatrix;  //3*3 16bit的矩阵[需要外部传入，用与YUV转RGB]
        void main(void){
            //思考精度问题
            mediump vec3 YUV;
            lowp vec3 RGB;
            
            YUV.x = texture2D(YtexSampler, v_textCoordinate).r;
            YUV.yz = texture2D(UVtexSampler, v_textCoordinate).ra - vec2(0.5, 0.5);
            RGB = colorMatrix * YUV;
         
            gl_FragColor = vec4(RGB, 1.0);
        }
     );
}

- (NSString *)unFullRangeFragmentShader{
    return GLSL_To_String
    (
        varying highp vec2 v_textCoordinate;  //接收纹理坐标
        uniform sampler2D YtexSampler;  //预设Y纹理坐标
        uniform sampler2D UVtexSampler;  //预设UV纹理坐标
        uniform mediump mat3 colorMatrix;  //3*3 16bit的矩阵
        void main(void){
            //思考精度问题
            mediump vec3 YUV;
            lowp vec3 RGB;
         
            YUV.x = texture2D(YtexSampler, v_textCoordinate).r - (16.0 / 255.0);
            YUV.yz = texture2D(UVtexSampler, v_textCoordinate).ra - vec2(0.5, 0.5);
            RGB = colorMatrix * YUV;
         
            gl_FragColor = vec4(RGB, 1.0);
        }
     );
}

@end
