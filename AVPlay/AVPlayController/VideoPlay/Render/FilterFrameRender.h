//
//  FilterFrameRender.h
//  AVPlay
//
//  Created by kakiYen on 2019/9/19.
//  Copyright © 2019 kakiYen. All rights reserved.
//

#import "CommonUtility.h"

NS_ASSUME_NONNULL_BEGIN

@interface FilterFrameRender : NSObject
@property (readonly, nonatomic) BOOL success;

- (instancetype)initWith:(GLint)width height:(GLint)height;

- (void)renderFrame:(GLuint)inTexturesHandle;

- (GLuint)getTexturesHandle;

- (void)destroyRender;

@end

NS_ASSUME_NONNULL_END
