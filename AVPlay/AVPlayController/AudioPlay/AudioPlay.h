//
//  AudioPlay.h
//  Audio and Video Play
//
//  Created by kakiYen on 2019/8/28.
//  Copyright © 2019 kakiYen. All rights reserved.
//

#import "CommonUtility.h"
#import "AudioHeader.h"

@protocol AudioRenderProtocol <NSObject>

- (void)retrieveCallback:(SInt16 * _Nullable)ioData numberFrames:(UInt32)numberFrames numberChannels:(UInt32)numberChannels;

@end

NS_ASSUME_NONNULL_BEGIN

@interface AudioPlay : NSObject

- (instancetype)initWith:(id<AudioRenderProtocol>)delegate;

- (void)setChannel:(UInt32)channel sampleRate:(double)sampleRate sampleFormat:(AudioSampleFormat)sampleFormat;

- (void)reStartAudio:(AudioPlayType)playType filePath:(NSString *_Nullable)filePath;

- (void)startAudio:(AudioPlayType)playType filePath:(NSString *_Nullable)filePath;

- (void)pauseAudioPaly;

- (void)closeAudioPaly;

@end

NS_ASSUME_NONNULL_END
