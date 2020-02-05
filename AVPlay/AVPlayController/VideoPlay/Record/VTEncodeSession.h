//
//  EncodeController.h
//  AVPlay
//
//  Created by kakiYen on 2019/11/11.
//  Copyright © 2019 kakiYen. All rights reserved.
//

#import <VideoToolbox/VideoToolbox.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, VTEncodeStatus) {
    UnOpenVTEncode,
    OpenedVTEncode,
    ClosedVTEncode,
};

@interface VTEncodeSession : NSObject

- (void)startEncoderSession:(CMSampleBufferRef)sampleBuffer;

- (void)closeEncoderSession;

@end

NS_ASSUME_NONNULL_END
