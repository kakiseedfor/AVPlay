//
//  AudioHeader.h
//  AVPlay
//
//  Created by kakiYen on 2019/10/31.
//  Copyright © 2019 kakiYen. All rights reserved.
//

#ifndef AudioHeader_h
#define AudioHeader_h

#import <AudioToolbox/AudioToolbox.h>

typedef NS_ENUM(NSInteger, AudioPlayType) {
    Audio_Play_Type,
    Audio_Record_Type,
    Audio_Encode_Type,
    Audio_PlayWithFile_Type,
};

typedef NS_ENUM(NSInteger, AudioPlayStatus) {
    Audio_Play_UnOpen,
    Audio_Play_Opened,
    Audio_Play_Paused,
    Audio_Play_Closed
};

typedef NS_ENUM(NSInteger, AudioEncodeStatus) {
    Audio_Encode_UnOpen,
    Audio_Encode_Opened,
    Audio_Encode_Closed
};

AudioComponentDescription IO_ACD(void);

AudioComponentDescription MCM_ACD(void);

AudioComponentDescription AUC_ACD(void);

AudioComponentDescription AFP_ACD(void);

AudioStreamBasicDescription MPEG4AAC_ASBD(Float64 sampleRate, UInt32 channle);

AudioStreamBasicDescription NonInterleavedPCM_ASBD(Float64 sampleRate,AudioFormatFlags formatFlags, UInt32 sampleFormatSize, UInt32 channle);

AudioStreamBasicDescription InterleavedPCM_ASBD(Float64 sampleRate, AudioFormatFlags formatFlags, UInt32 sampleFormatSize, UInt32 channle);

#endif /* AudioHeader_h */
