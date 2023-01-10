//
//  DisplayFrameRender.m
//  AVPlay
//
//  Created by kakiYen on 2019/9/20.
//  Copyright © 2019 kakiYen. All rights reserved.
//

#import "DisplayFrameRender.h"

@interface DisplayFrameRender ()
@property (nonatomic) GLuint framebuffer;
@property (nonatomic) GLuint renderbuffer;
@property (nonatomic) GLuint programHandle;

@end

@implementation DisplayFrameRender

- (void)dealloc{
    NSLog(@"%s",__FUNCTION__);
}

- (void)destroyRender
{
    glBindTexture(GL_TEXTURE_2D, 0);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glBindRenderbuffer(GL_RENDERBUFFER, 0);
    glDeleteProgram(_programHandle);
    glDeleteFramebuffers(1, &_framebuffer);
    glDeleteRenderbuffers(1, &_renderbuffer);
    _success = NO;
    _framebuffer = 0;
    _renderbuffer = 0;
    
    NSLog(@"%s",__FUNCTION__);
}

- (instancetype)initWith:(CAEAGLLayer *)layer glContext:(EAGLContext *)glContext
{
    self = [super init];
    if (self) {
        [self initialBuffer:layer glContext:glContext];
    }
    return self;
}

- (void)initialBuffer:(CAEAGLLayer *)layer glContext:(EAGLContext *)glContext{
    glGenFramebuffers(1, &_framebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
    glGenRenderbuffers(1, &_renderbuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
    [glContext renderbufferStorage:GL_RENDERBUFFER fromDrawable:layer];    //绑定当前渲染缓冲区
    
    /*
     设置双线性平滑过滤方式
     */
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_width);   //获取context宽
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_height); //获取context高
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _renderbuffer);    //将帧缓冲区与渲染缓冲区绑定
    
    glClearColor(0.f, 0.f, 0.f, 1.f);   //设置渲染背景
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    /*
     设置颜色混合可用
     */
    glEnable(GL_BLEND); //启用纹理与上下文环境颜色混合
    /*
     源颜色是纹理，目标颜色是GLContext的颜色
     */
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    
    if (!CheckFramebufferStatus()) {
        NSLog(@"Initial DisplayFrameRender Fail!");
        [self destroyRender];
        return;
    }
    
    GLuint vertexHandle = CompileShader(self.vertexShader, GL_VERTEX_SHADER);
    GLuint fragmentHandle = CompileShader(self.fragmentShader, GL_FRAGMENT_SHADER);
    _programHandle = CompileProgram(vertexHandle, fragmentHandle);
    
    if (!_programHandle) {
        NSLog(@"Complie DisplayFrameRender Fail!");
        [self destroyRender];
        return;
    }
    
    _success = YES;
//    glBindTexture(GL_TEXTURE_2D, 0);
//    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glBindRenderbuffer(GL_RENDERBUFFER, 0);
}

/*
 以下的调用顺序非常严格：
 1、将需要操作的glContext绑定到OpenGL(即启用哪个glContext与OpenGL进行连接)
 2、设置OpenGL纹理坐标
 3、使用GLSL程序
 4、将需要操作的Framebuffer绑定到Render Pipe(即需要操作哪个Framebuffer)，将纹理绘制到Framebuffer
 5、将需要操作的Renderbuffer绑定到Render Pipe(即需要操作哪个Renderbuffer)
 6、glContext将Framebuffer的内容交换到Renderbuffer
 */
- (void)renderFrame:(GLuint)inTexturesHandle aspectRatio:(CGFloat)aspectRatio{
    glViewport(0, 0, _width, _height);
    
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
        0.f + aspectRatio, 0.f + aspectRatio,
        1.f - aspectRatio, 0.f + aspectRatio,
        0.f + aspectRatio, 1.f - aspectRatio,
        1.f - aspectRatio, 1.f - aspectRatio,
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
    
    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);  //将纹理渲染到帧缓冲 Framebuffers
    glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
    
    glBindTexture(GL_TEXTURE_2D, 0);    //取消对 _texturesHandle 这个纹理操作
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
//    GLenum code = glGetError();
//    NSLog(@"%s code %d",__FUNCTION__,code);
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
