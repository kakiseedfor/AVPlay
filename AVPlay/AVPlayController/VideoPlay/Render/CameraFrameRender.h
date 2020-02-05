//
//  CameraFrameRender.h
//  AVPlay
//
//  Created by kakiYen on 2019/11/11.
//  Copyright © 2019 kakiYen. All rights reserved.
//

#import <OpenGLES/ES2/gl.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface CameraFrameRender : NSObject
@property (readonly, nonatomic) BOOL success;

- (instancetype)initWith:(EAGLContext *)glContext isFullRange:(BOOL)isFullRange width:(size_t)width height:(size_t)height;

- (void)renderFrame:(CVImageBufferRef)cameraFrame;

- (GLuint)getTexturesHandle;

- (void)destroyRender;

@end

NS_ASSUME_NONNULL_END
