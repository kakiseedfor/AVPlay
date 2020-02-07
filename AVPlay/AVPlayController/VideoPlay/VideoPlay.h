//
//  PngPreview.h
//  Audio and Video Play
//
//  Created by kakiYen on 2019/8/20.
//  Copyright © 2019 kakiYen. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CommonUtility.h"

typedef NS_ENUM(NSInteger, VideoPlayStatus) {
    UnOpenVideoPlay,
    OpenedVideoPlay,
    ClosedVideoPlay,
};

NS_ASSUME_NONNULL_BEGIN

@interface VideoPlay : UIView
@property (readonly, nonatomic) VideoPlayStatus status;

- (void)restartRender:(Video_Frame *)videoFrame width:(int)pixelWidth height:(int)pixelHeight;

- (void)startRender:(Video_Frame *)videoFrame width:(int)pixelWidth height:(int)pixelHeight;

- (void)setParentView:(UIView *)parentView;

- (void)closeVideoPlay;

@end

NS_ASSUME_NONNULL_END
