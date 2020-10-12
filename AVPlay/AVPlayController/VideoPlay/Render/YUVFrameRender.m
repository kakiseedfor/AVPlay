//
//  YUVFrameRender.m
//  AVPlay
//
//  Created by kakiYen on 2019/9/19.
//  Copyright © 2019 kakiYen. All rights reserved.
//

#import "YUVFrameRender.h"

@interface YUVFrameRender (){
    GLuint inTexturesHandle[3];
}
@property (nonatomic) GLuint outTexturesHandle;
@property (nonatomic) GLuint programHandle;
@property (nonatomic) GLuint framebuffer;
@property (nonatomic) GLuint height;
@property (nonatomic) GLuint width;

@end

@implementation YUVFrameRender

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
    for (int i = 0; i < 3; i++) {
        glDeleteTextures(1, &inTexturesHandle[i]);
        inTexturesHandle[i] = 0;
    }
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
    [self initialInTextures];
    [self initialOutTextures];
    
    /*
     将帧缓冲 GL_FRAMEBUFFER 输出到 texturesHandle 纹理中
     */
    glGenFramebuffers(1, &_framebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _outTexturesHandle, 0);
    
    if (!CheckFramebufferStatus()) {
        NSLog(@"Initial YUVFrameRender Fail!");
        [self destroyRender];
        return;
    }
    
    GLuint vertexHandle = CompileShader(self.vertexShader, GL_VERTEX_SHADER);
    GLuint fragmentHandle = CompileShader(self.fragmentShader, GL_FRAGMENT_SHADER);
    _programHandle = CompileProgram(vertexHandle, fragmentHandle);
    
    if (!_programHandle) {
        NSLog(@"Complie YUVFrameRender Fail!");
        [self destroyRender];
        return;
    }
    
    _success = YES;
    glBindTexture(GL_TEXTURE_2D, 0);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
}

- (void)initialInTextures{
    [self initialTextures:&inTexturesHandle[0]];
    [self initialTextures:&inTexturesHandle[1]];
    [self initialTextures:&inTexturesHandle[2]];
    for (int i = 0; i < 3; i++) {
        glBindTexture(GL_TEXTURE_2D, inTexturesHandle[i]);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_LUMINANCE, _width, _height, 0, GL_LUMINANCE, GL_UNSIGNED_BYTE, NULL);
    }
}

- (void)initialOutTextures{
    [self initialTextures:&_outTexturesHandle];
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, _width, _height, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
}

- (void)initialTextures:(GLuint *)texturesHandle{
    glGenTextures(1, texturesHandle);
    glBindTexture(GL_TEXTURE_2D, *texturesHandle);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);   //放大处理方式
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);   //缩小处理方式
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
}

/*
 Open GL渲染管线流程
 1、指定几何图元的绘制规则。
 2、顶点处理->处理物体坐标、纹理坐标。
 3、图元组装->根据 阶段1 指定的规则及 阶段2 设定的坐标，生成图元数据。
 4、栅格化->将 阶段3 的图元数据，分解对应到缓冲区中的各个像素，这些更小单元成为片元。
 5、片元处理->针对 阶段4 形成的片元，从纹理中获取到对应的像素值。
 6、帧缓冲操作->将 阶段5 处理过的片元写入到缓冲区中。
 */
- (void)renderFrame:(Video_Frame *)videoFrame{
    [self fillInTextures:videoFrame];
    
    glViewport(0, 0, _width, _height);  //视图窗口的位置
    glUseProgram(_programHandle);   //使用之前必须先指定帧缓冲区
    
    //纹理占据整个视图窗口
    GLfloat imageVertex[] = {   //纹理占据视图窗口中的哪个位置，即纹理的顶点在视图窗口中哪一部分显示[中心点(0, 0)]
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
     设置纹理坐标，以及指明纹理显示部分
     初始坐标为:{
        0.f, 0.f,
        1.f, 0.f,
        0.f, 1.f,
        1.f, 1.f,
     }
     需转换成对应的计算机坐标
     */
    GLfloat texturesVertex[] = {
        0.f, 1.f,
        1.f, 1.f,
        0.f, 0.f,
        1.f, 0.f,
    };
    int textCoordinate = glGetAttribLocation(_programHandle, "textCoordinate");
    glVertexAttribPointer(textCoordinate, 2, GL_FLOAT, GL_FALSE, 0, texturesVertex);
    glEnableVertexAttribArray(textCoordinate);
    
    /*
     设置片元着色器的变量 YtexSampler。
     */
    glActiveTexture(GL_TEXTURE0);   //激活哪个纹理单元
    glBindTexture(GL_TEXTURE_2D, inTexturesHandle[0]);  //指定要操作的纹理
    int YtexSampler = glGetUniformLocation(_programHandle, "YtexSampler");    //获取 GLSL 里的 "YtexSampler" 变量
    glUniform1i(YtexSampler, 0); //将 GL_TEXTURE0 纹理单元赋值到 YtexSampler

    /*
     设置片元着色器的变量 UtexSampler。
     */
    glActiveTexture(GL_TEXTURE1);   //激活哪个纹理单元
    glBindTexture(GL_TEXTURE_2D, inTexturesHandle[1]);  //指定要操作的纹理
    int UtexSampler = glGetUniformLocation(_programHandle, "UtexSampler");    //获取 GLSL 里的 "UtexSampler" 变量
    glUniform1i(UtexSampler, 1); //将 GL_TEXTURE1 纹理单元赋值到 UtexSampler

    /*
     设置片元着色器的变量 VtexSampler。
     */
    glActiveTexture(GL_TEXTURE2);   //激活哪个纹理单元
    glBindTexture(GL_TEXTURE_2D, inTexturesHandle[2]);  //指定要操作的纹理
    int VtexSampler = glGetUniformLocation(_programHandle, "VtexSampler");    //获取 GLSL 里的 "VtexSampler" 变量
    glUniform1i(VtexSampler, 2); //将 GL_TEXTURE2 纹理单元赋值到 VtexSampler
    
    /*
     @mode 指定几何图元的绘制方式(以三角形绘制)
     @first 从哪个顶点开始
     @count 顶点数量
     */
    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);  //将纹理渲染到帧缓冲 Framebuffers
    glBindTexture(GL_TEXTURE_2D, 0);    //取消对 _texturesHandle 这个纹理操作
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
//    GLenum code = glGetError();
//    NSLog(@"%s code %d",__FUNCTION__,code);
}

/*
 将YUV数据分别渲染到各自的纹理中
 */
- (void)fillInTextures:(Video_Frame *)videoFrame{
    const void *pixels[] = {videoFrame.data.bytes, videoFrame.crData.bytes, videoFrame.cbData.bytes};
    int heights[] = {videoFrame.height, videoFrame.height / 2, videoFrame.height / 2};
    int widths[] = {videoFrame.width, videoFrame.width / 2, videoFrame.width / 2};
    
    for (int i = 0; i < 3; i++) {
        glBindTexture(GL_TEXTURE_2D, inTexturesHandle[i]);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_LUMINANCE, widths[i], heights[i], 0, GL_LUMINANCE, GL_UNSIGNED_BYTE, pixels[i]);
    }
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
        uniform sampler2D YtexSampler;  //预设Y纹理坐标
        uniform sampler2D UtexSampler;  //预设U纹理坐标
        uniform sampler2D VtexSampler;  //预设V纹理坐标
        void main(void){
            highp float Y = texture2D(YtexSampler, v_textCoordinate).r;
            highp float U = texture2D(UtexSampler, v_textCoordinate).r - 0.5;
            highp float V = texture2D(VtexSampler, v_textCoordinate).r - 0.5;

            highp float R = Y + 1.402 * V;
            highp float G = Y - 0.34414 * U - 0.71414 * V;
            highp float B = Y + 1.772 * U;
            gl_FragColor = vec4(R, G, B, 1.0);
        }
     );
}

@end
