//
//  AudioHeader.m
//  AVPlay
//
//  Created by kakiYen on 2019/11/9.
//  Copyright © 2019 kakiYen. All rights reserved.
//

#import "AudioHeader.h"

#pragma mark - Audio Component Description

//音频输入输出节点描述
AudioComponentDescription IO_ACD(){
    return (AudioComponentDescription){
        kAudioUnitType_Output,  //定义I/O单元
        kAudioUnitSubType_RemoteIO, //使用I/O单元中的麦克风或扬声器
        kAudioUnitManufacturer_Apple,
        0,
        0,
    };
};

//音频文件输入节点描述
AudioComponentDescription AFP_ACD(){
    return (AudioComponentDescription){
        kAudioUnitType_Generator,   //定义生成器单元
        kAudioUnitSubType_AudioFilePlayer,  //使用生成器单元的媒体文件作为输入
        kAudioUnitManufacturer_Apple,
        0,
        0,
    };
}

//音频格式转换节点描述
AudioComponentDescription AUC_ACD(){
    return (AudioComponentDescription){
        kAudioUnitType_FormatConverter,   //定义格式转换单元
        kAudioUnitSubType_AUConverter, //使用格式转换单元的量化格式转换
        kAudioUnitManufacturer_Apple,
        0,
        0,
    };
}

//音频混合器描述
AudioComponentDescription MCM_ACD(){
    return (AudioComponentDescription){
        kAudioUnitType_Mixer,   //定义混合器单元
        kAudioUnitSubType_MultiChannelMixer,    //使用混合器单元的多路声音混合器
        kAudioUnitManufacturer_Apple,
        0,
        0,
    };
}

#pragma mark - Audio Stream Basic Description

AudioStreamBasicDescription NonInterleavedPCM_ASBD(Float64 sampleRate,AudioFormatFlags formatFlags, UInt32 sampleFormatSize, UInt32 channle){
    return (AudioStreamBasicDescription){
        sampleRate,  //采样率
        kAudioFormatLinearPCM,  //编码格式
        formatFlags | kAudioFormatFlagIsNonInterleaved,  //量化格式 | 非交错型
        sampleFormatSize,   //每个Packet的大小
        1,  //每个Packet有多少个Frame
        sampleFormatSize,   //每个Frame的大小
        channle,   //声道数
        sampleFormatSize * 8,   //每个声道的音频数据大小所占的位数
    };
}

AudioStreamBasicDescription InterleavedPCM_ASBD(Float64 sampleRate, AudioFormatFlags formatFlags, UInt32 sampleFormatSize, UInt32 channle){
    return (AudioStreamBasicDescription){
        sampleRate,  //采样率
        kAudioFormatLinearPCM,  //编码格式
        formatFlags,  //量化格式 | 交错型
        sampleFormatSize * channle,   //每个Packet的大小
        1,  //每个Packet有多少个Frame
        sampleFormatSize * channle,   //每个Frame的大小
        channle,   //声道数
        sampleFormatSize * 8,   //每个声道的音频数据大小所占的位数
    };
}

AudioStreamBasicDescription MPEG4AAC_ASBD(Float64 sampleRate, UInt32 channle){
    return (AudioStreamBasicDescription){
        sampleRate,  //采样率
        kAudioFormatMPEG4AAC,  //指定为MPEG4-AAC编码格式
        kMPEG4Object_AAC_LC,  //无损编码
        0,
        1024,  //AAC编码格式中每个压缩包固定有1024帧
        0,
        channle,   //声道数
        0,
    };
}
