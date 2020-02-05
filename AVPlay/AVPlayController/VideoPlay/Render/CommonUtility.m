//
//  CommonUtility.m
//  AVPlay
//
//  Created by kakiYen on 2019/9/20.
//  Copyright © 2019 kakiYen. All rights reserved.
//

#import "CommonUtility.h"

GLuint CompileProgram(GLuint vertexHandle, GLuint fragmentHandle){
    if (!vertexHandle || !fragmentHandle) {
        return 0;
    }
    GLuint program = glCreateProgram();
    
    glAttachShader(program, vertexHandle);
    glAttachShader(program, fragmentHandle);
    glLinkProgram(program);
    
    GLint status = 0;
    glGetProgramiv(program, GL_LINK_STATUS, &status);
    if (status == GL_FALSE) {
        NSLog(@"Failed to link program %d", program);
        glDeleteProgram(program);
        program = 0;
        return program;
    }
    
    glValidateProgram(program);
    glGetProgramiv(program, GL_VALIDATE_STATUS, &status);
    if (status == GL_FALSE) {
        NSLog(@"Failed to validate program %d", program);
        
        GLint logLength = 0;
        glGetProgramiv(program, GL_INFO_LOG_LENGTH, &logLength);
        if (logLength) {
            GLchar *errorlog = (GLchar *)malloc(logLength);
            glGetProgramInfoLog(program, logLength, &logLength, errorlog);
            NSLog(@"%s",errorlog);
            free(errorlog);
        }
        glDeleteProgram(program);
        program = 0;
    }
    
    return program;
}

GLuint CompileShader(NSString *shader, GLuint type){
    if (!shader.length) {
        return 0;
    }
    
    GLuint shaderHandle = glCreateShader(type);
    const GLchar *CShader = (GLchar *)shader.UTF8String;
    glShaderSource(shaderHandle, 1, &CShader, NULL);
    glCompileShader(shaderHandle);
    
    GLint status = 0;
    glGetShaderiv(shaderHandle, GL_COMPILE_STATUS, &status);
    if (status == GL_FALSE) {
        GLint logLength = 0;
        glGetShaderiv(shaderHandle, GL_INFO_LOG_LENGTH, &logLength);
        
        GLchar *errorlog = (GLchar *)malloc(logLength);
        glGetShaderInfoLog(shaderHandle, logLength, &logLength, errorlog);
        NSLog(@"%s",errorlog);
        
        free(errorlog);
        glDeleteShader(shaderHandle);
        shaderHandle = 0;
    }
    
    return shaderHandle;
};

void HasAuthorization(AVMediaType _Nonnull mediaType, void(^ _Nullable grantedBlock)(BOOL granted)){
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:mediaType];
    
    if (device) {
        AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:mediaType];
        switch (authStatus) {
            case AVAuthorizationStatusRestricted:
            case AVAuthorizationStatusDenied:
                break;
            case AVAuthorizationStatusNotDetermined:
                [AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio completionHandler:grantedBlock];
                break;
            default:
                !grantedBlock ? : grantedBlock(YES);
                break;
        }
    }
}

void FitSizeToView(CGRect originalRect, CGSize targetSize, CGRect *returnRect, CGFloat *aspectRatio){
    CGFloat superWidth = CGRectGetWidth(originalRect);
    CGFloat superHeight = CGRectGetHeight(originalRect);
    
    CGFloat width = 0.f;
    CGFloat height = 0.f;
    CGFloat widthRatio = (CGFloat)superWidth / targetSize.width;
    CGFloat heightRatio = (CGFloat)superHeight / targetSize.height;
    
    if (widthRatio < heightRatio) {
        width = MIN(superWidth, targetSize.width);
        height = targetSize.height * widthRatio;
    }else if (widthRatio > heightRatio){
        width = targetSize.width * heightRatio;
        height = MIN(superHeight, targetSize.height);
    }else{
        width = targetSize.width * widthRatio;
        height = targetSize.height * heightRatio;
    }
    
    *returnRect = CGRectMake((superWidth - width) / 2, (superHeight - height) / 2, width, height);
    
    if (ABS(CGRectGetWidth(originalRect) - CGRectGetWidth(*returnRect)) > 0.f ) {
        if (ABS(CGRectGetHeight(originalRect) - CGRectGetHeight(*returnRect)) > 1.f ) {
            
        }else{
            *aspectRatio = (CGRectGetWidth(originalRect) - CGRectGetWidth(*returnRect)) / (2 * CGRectGetWidth(originalRect));
            *returnRect = CGRectMake(0.f, CGRectGetMinY(*returnRect), CGRectGetWidth(originalRect), CGRectGetHeight(*returnRect));
        }
    }
}

void VerifyStatus(OSStatus status, NSString *errorMsg, BOOL isAbort){
    if (status != noErr) {
        NSLog(@"%@ : %d",errorMsg, (int)status);
        !isAbort ? : abort();
    }
}

BOOL CheckFramebufferStatus(void){
    BOOL success = YES;
    GLenum error = glGetError();
    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if (status != GL_FRAMEBUFFER_COMPLETE || error != GL_NO_ERROR) {
        success = NO;
    }
    return success;
}

@implementation AV_Frame
@end

@implementation Audio_Frame
@end

@implementation Video_Frame
@end
