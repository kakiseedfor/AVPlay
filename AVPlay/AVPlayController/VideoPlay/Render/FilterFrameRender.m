//
//  FilterFrameRender.m
//  AVPlay
//
//  Created by kakiYen on 2019/9/19.
//  Copyright © 2019 kakiYen. All rights reserved.
//

#import "FilterFrameRender.h"

@interface FilterFrameRender ()
@property (nonatomic) GLuint outTexturesHandle;
@property (nonatomic) GLuint programHandle;
@property (nonatomic) GLuint framebuffer;
@property (nonatomic) GLuint height;
@property (nonatomic) GLuint width;

@end

@implementation FilterFrameRender

- (void)dealloc{
    NSLog(@"%s",__FUNCTION__);
}

- (void)destroyRender
{
    glBindTexture(GL_TEXTURE_2D, 0);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glDeleteProgram(_programHandle);
    glDeleteTextures(1, &_outTexturesHandle);
    glDeleteFramebuffers(1, &_framebuffer);
    _success = NO;
    _framebuffer = 0;
    _programHandle = 0;
    _outTexturesHandle = 0;
    
    NSLog(@"%s",__FUNCTION__);
}

- (instancetype)initWith:(GLint)width height:(GLint)height
{
    self = [super init];
    if (self) {
        _width = width;
        _height = height;
        
        [self initialBuffer];
    }
    return self;
}

- (void)initialBuffer{
    glGenTextures(1, &_outTexturesHandle);
    glBindTexture(GL_TEXTURE_2D, _outTexturesHandle);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);   //放大处理方式
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);   //缩小处理方式
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, _width, _height, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
    
    /*
     将帧缓冲 GL_FRAMEBUFFER 输出到 texturesHandle 纹理中
     */
    glGenFramebuffers(1, &_framebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _outTexturesHandle, 0);
    
    if (!CheckFramebufferStatus()) {
        NSLog(@"Initial FilterFrameRender Fail!");
        [self destroyRender];
        return;
    }
    
    GLuint vertexHandle = CompileShader(self.vertexShader, GL_VERTEX_SHADER);
    GLuint fragmentHandle = CompileShader(self.fragmentShader, GL_FRAGMENT_SHADER);
    _programHandle = CompileProgram(vertexHandle, fragmentHandle);
    
    if (!_programHandle) {
        NSLog(@"Complie FilterFrameRender Fail!");
        [self destroyRender];
        return;
    }
    
    _success = YES;
    glBindTexture(GL_TEXTURE_2D, 0);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
}

- (void)renderFrame:(GLuint)inTexturesHandle{
    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
    glUseProgram(_programHandle);
    
    //图片物体坐标度，按原图行缩小 1/2。
    GLfloat imageVertex[] = {
        -1.f,-1.f,
        1.f,-1.f,
        -1.f,1.f,
        1.f,1.f,
    };
    /*
     设置顶点着色器的变量 vertexPosition。
     */
    int vertexPosition = glGetAttribLocation(_programHandle, "vertexPosition");
    glVertexAttribPointer(vertexPosition, 2, GL_FLOAT, GL_FALSE, 0, imageVertex);
    glEnableVertexAttribArray(vertexPosition);
    
    /*
     设置纹理坐标
     初始坐标为:{
        0.f, 0.f,
        1.f, 0.f,
        0.f, 1.f,
        1.f, 1.f,
     }
     需转换成对应的计算机坐标
     */
    GLfloat texturesVertex[] = {
        0.f, 0.f,
        1.f, 0.f,
        0.f, 1.f,
        1.f, 1.f,
    };
    int textCoordinate = glGetAttribLocation(_programHandle, "textCoordinate");
    glVertexAttribPointer(textCoordinate, 2, GL_FLOAT, GL_FALSE, 0, texturesVertex);
    glEnableVertexAttribArray(textCoordinate);
    
    /*
     设置片元着色器的变量 texSampler。
     */
    glActiveTexture(GL_TEXTURE0);   //激活哪个纹理单元
    glBindTexture(GL_TEXTURE_2D, inTexturesHandle);  //指定要操作的纹理
    int texSampler = glGetUniformLocation(_programHandle, "texSampler");    //获取 GLSL 里的 "texSampler" 变量
    glUniform1i(texSampler, 0); //将 GL_TEXTURE0 纹理单元赋值到 texSampler
    
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

@end
