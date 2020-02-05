//
//  VideoPreview.h
//  AVPlay
//
//  Created by kakiYen on 2019/11/11.
//  Copyright © 2019 kakiYen. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, VideoPreviewStatus) {
    UnOpenVideoPreview,
    OpenedVideoPreview,
    ClosedVideoPreview,
};

typedef NS_ENUM(NSInteger, VideoRecordStatus) {
    OpenVideoRecord,
    OpenedVideoRecord,
    ClosedVideoRecord,
};

NS_ASSUME_NONNULL_BEGIN

@interface VideoPreview : UIView

- (void)reStartRender:(CVImageBufferRef)imageBufferRef timingInfo:(CMSampleTimingInfo)timingInfo isfrontCamera:(BOOL)isfrontCamera isFullRange:(BOOL)isFullRange;

- (void)startRender:(CVImageBufferRef)imageBufferRef timingInfo:(CMSampleTimingInfo)timingInfo isfrontCamera:(BOOL)isfrontCamera isFullRange:(BOOL)isFullRange;

- (void)setParentView:(UIView *)parentView;

- (void)setOpenRecord:(BOOL)openRecord;

- (void)closeVideoPreview;

@end

NS_ASSUME_NONNULL_END
