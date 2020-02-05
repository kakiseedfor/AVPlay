//
//  AudioSessionManager.h
//  Audio and Video Play
//
//  Created by kakiYen on 2019/8/26.
//  Copyright © 2019 kakiYen. All rights reserved.
//

#import "AudioHeader.h"

NS_ASSUME_NONNULL_BEGIN

@interface AudioSession : NSObject

+ (instancetype)shareInstance;

- (BOOL)userSpeaker;

- (void)setActive:(BOOL)active;

- (void)setCategory:(NSString *)category;

- (void)setSampleRate:(double)sampleRate;

- (void)setBufferDuration:(NSTimeInterval)bufferDuration;

- (void)dealRouteChange:(AudioPlayType)playType;

@end

NS_ASSUME_NONNULL_END
