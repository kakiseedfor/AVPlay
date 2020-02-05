//
//  DisplayFrameRender.h
//  AVPlay
//
//  Created by kakiYen on 2019/9/20.
//  Copyright © 2019 kakiYen. All rights reserved.
//

#import "CommonUtility.h"

NS_ASSUME_NONNULL_BEGIN

@interface DisplayFrameRender : NSObject
@property (readonly, nonatomic) GLint width;
@property (readonly, nonatomic) GLint height;
@property (readonly, nonatomic) BOOL success;

- (instancetype)initWith:(CAEAGLLayer *)layer glContext:(EAGLContext *)glContext;

- (void)renderFrame:(GLuint)inTexturesHandle aspectRatio:(CGFloat)aspectRatio;

- (void)destroyRender;

@end

NS_ASSUME_NONNULL_END
