//
//  Decoder.h
//  AVPlay
//
//  Created by kakiYen on 2019/9/4.
//  Copyright © 2019 kakiYen. All rights reserved.
//

#import "CommonUtility.h"

typedef NS_ENUM(NSInteger, DecoderStatus) {
    DecoderUnOpen,
    DecoderOpened,
    DecoderDecoding,
    DecoderPause,
    DecoderClosed,
};

NS_ASSUME_NONNULL_BEGIN

@protocol DecoderDelegate <NSObject>

- (void)decodedVideoPacket:(Video_Frame *)videoFrame;

- (void)decodedAudioPacket:(Audio_Frame *)audioFrame;

- (void)statusCallBack:(DecoderStatus)status;

@end

@interface Decoder : NSObject
@property (readonly, nonatomic) DecoderStatus status;
@property (readonly, nonatomic) BOOL endOfFile;


- (instancetype)initWith:(NSString *)filePath delegate:(id<DecoderDelegate>)delegate;

- (void)openDecoder;   //打开编码器

- (void)resumeDecoder;  //开始或继续编码

- (void)pauseDecoder;   //暂停编码

- (void)closeDecoder;   //关闭编码

@end

NS_ASSUME_NONNULL_END
