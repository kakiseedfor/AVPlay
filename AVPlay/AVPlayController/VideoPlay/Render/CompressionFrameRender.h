//
//  CompressionFrameRender.h
//  AVPlay
//
//  Created by kakiYen on 2019/11/25.
//  Copyright © 2019 kakiYen. All rights reserved.
//

#import "CommonUtility.h"

@protocol VideoCompressionDelegate <NSObject>

- (void)finishConvertToSampleBuffer:(CMSampleBufferRef _Nullable)sampleBuffer;

@end

NS_ASSUME_NONNULL_BEGIN

@interface CompressionFrameRender : NSObject
@property (readonly, nonatomic) BOOL success;

- (void)destroyRender;

- (instancetype)initWith:(size_t)width height:(size_t)height delegate:(id<VideoCompressionDelegate>)delegate;

- (void)renderFrame:(GLuint)inTexturesHandle timingInfo:(CMSampleTimingInfo)timingInfo;

@end

NS_ASSUME_NONNULL_END
