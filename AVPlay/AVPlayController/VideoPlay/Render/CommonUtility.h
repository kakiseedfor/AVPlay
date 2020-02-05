//
//  CommonUtility.h
//  AVPlay
//
//  Created by kakiYen on 2019/9/20.
//  Copyright © 2019 kakiYen. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <OpenGLES/ES2/glext.h>
#import <OpenGLES/ES2/gl.h>
#import <UIKit/UIKit.h>

void FitSizeToView(CGRect originalRect, CGSize targetSize, CGRect * _Nonnull returnRect, CGFloat * _Nonnull aspectRatio);

void HasAuthorization(AVMediaType _Nonnull mediaType, void(^ _Nullable grantedBlock)(BOOL granted));

void VerifyStatus(OSStatus status, NSString * _Nullable errorMsg, BOOL isAbort);

GLuint CompileProgram(GLuint vertexHandle, GLuint fragmentHandle);

GLuint CompileShader(NSString * _Nullable shader, GLuint type);

BOOL CheckFramebufferStatus(void);

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, AV_FrameType) {
    VideoFrameType,
    AudioFrameType,
};

typedef NS_ENUM(NSInteger, AudioSampleFormat) {
    AUDIO_SAMPLE_FMT_S16
};

@interface AV_Frame : NSObject
@property (strong, nonatomic) NSData * _Nullable data;
@property (nonatomic) AV_FrameType frameType;
@property (nonatomic) CGFloat position;
@property (nonatomic) CGFloat duration;

@end

@interface Audio_Frame : AV_Frame
@property (nonatomic) AudioSampleFormat sampleFormat;   //量化格式
@property (nonatomic) int nbSamples;
@property (nonatomic) int channels;

@end

@interface Video_Frame : AV_Frame
@property (strong, nonatomic) NSData * _Nullable crData;
@property (strong, nonatomic) NSData * _Nullable cbData;
@property (nonatomic) int height;
@property (nonatomic) int width;

@end

NS_ASSUME_NONNULL_END
