//
//  AudioPlay.m
//  Audio and Video Play
//
//  Created by kakiYen on 2019/8/28.
//  Copyright © 2019 kakiYen. All rights reserved.
//

#import "NSDate+String.h"
#import "AudioSession.h"
#import "AudioPlay.h"

static OSStatus RenderCallback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData);

static OSStatus AU_RenderCallback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData);

static OSStatus InInputDataProc(AudioConverterRef inAudioConverter, UInt32 *ioNumberDataPackets, AudioBufferList *ioData, AudioStreamPacketDescription * _Nullable *outDataPacketDescription, void *inUserData);

@interface AudioPlay (){
    AudioConverterRef _converterRef;
    ExtAudioFileRef _extRef;
    uint8_t *_packetBuffer;
    uint8_t *_PCMBuffer;
    SInt16 *_bufferData;
    AUGraph _auGraph;
}
@property (strong, nonatomic) dispatch_semaphore_t semaphore;   //貌似有先来后到的意思
@property (strong, nonatomic) dispatch_queue_t dispatchQueue;
@property (weak, nonatomic) id<AudioRenderProtocol> delegate;
@property (nonatomic) AUNode ioNode;
@property (nonatomic) AUNode fileNode;
@property (nonatomic) AUNode formatNode;
@property (nonatomic) AUNode mixerNode;
@property (nonatomic) UInt32 channel;
@property (nonatomic) UInt32 bufferSize;
@property (nonatomic) UInt32 packetSize;
@property (nonatomic) UInt32 PCMBufferSize;
@property (nonatomic) double sampleRate;
@property (nonatomic) BOOL openRecord;
@property (nonatomic) AudioPlayStatus playStatus;
@property (nonatomic) AudioEncodeStatus encodeStatus;
@property (nonatomic) AudioSampleFormat sampleFormat;

@property (strong, nonatomic) NSFileHandle *encodeFileHandle;
@property (strong, nonatomic) NSFileHandle *PCMFileHandle;

@end

@implementation AudioPlay

- (void)dealloc
{
    NSLog(@"%s",__FUNCTION__);
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _channel = 2;
        _sampleRate = 44100;
        _playStatus = Audio_Play_UnOpen;
        _sampleFormat = AUDIO_SAMPLE_FMT_S16;
        _encodeStatus = Audio_Encode_UnOpen;
        _semaphore = dispatch_semaphore_create(1);
        _dispatchQueue = dispatch_queue_create("AudioPlay.Queue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (instancetype)initWith:(id<AudioRenderProtocol>)delegate
{
    self = [self init];
    if (self) {
        _delegate = delegate;
    }
    return self;
}

- (void)setChannel:(UInt32)channel sampleRate:(double)sampleRate sampleFormat:(AudioSampleFormat)sampleFormat{
    _channel = channel;
    _sampleRate = sampleRate;
    _sampleFormat = sampleFormat;
}

/*
 初始化音频节点
 */
- (void)openAudio:(AudioPlayType)playType filePath:(NSString *)filePath{
    //生成音频表
    VerifyStatus(NewAUGraph(&_auGraph), @"Could not create AUGraph", YES);
    
    NSString *category = AVAudioSessionCategorySoloAmbient;
    switch (playType) {
        case Audio_Play_Type:
            category = AVAudioSessionCategoryPlayback;
            [self openAudioPaly];
            break;
        case Audio_Record_Type:
            category = AVAudioSessionCategoryPlayAndRecord;
            [self openAudioRecord];
            break;
        case Audio_Encode_Type:
            [self openAudioEncode:filePath];
            break;
        case Audio_PlayWithFile_Type:
            category = AVAudioSessionCategoryPlayback;
            [self openAudioPlayWithFile:filePath];
            break;
        default:
            break;
    }
    //必须要初始化音频表
    VerifyStatus(AUGraphInitialize(_auGraph), @"Initialize AUGraph fail", YES);
    //显示音频表
    CAShow(_auGraph);
    
    //初始化音频表AUGraph后，才可以对音频节点设置音频文件属性
    switch (playType) {
        case Audio_Record_Type:
            [self openExtAudioFile:filePath];
            break;
        case Audio_PlayWithFile_Type:
            [self openAudioFileRegion:filePath];
            break;
        default:
            break;
    }
    
    [AudioSession.shareInstance dealRouteChange:playType];
    [AudioSession.shareInstance setSampleRate:_sampleRate];
    [AudioSession.shareInstance setCategory:category];
    [AudioSession.shareInstance setActive:YES];
    
    self.playStatus = Audio_Play_Opened;
}

/*
 仅音频播放功能
 */
- (void)openAudioPaly{
    //创建音频输出节点
    AudioComponentDescription ioACD = IO_ACD();
    VerifyStatus(AUGraphAddNode(_auGraph, &ioACD, &_ioNode), @"Could not add node with type is Output and subType is RemoteIO to AUGraph", YES);
    
    //创建音频格式转换节节点
    AudioComponentDescription aucACD = AUC_ACD();
    VerifyStatus(AUGraphAddNode(_auGraph, &aucACD, &_formatNode), @"Could not add node with type is FormatConverter and subType is Splitter to AUGraph", YES);
    
    //在获取Audio Unit之前必须打开AuGraph，否则获取错误。
    AUGraphOpen(_auGraph);
    
#pragma mark - Init Audio Stream Basic Description
    
    /*
     Scope: { scope output, element 0 = output } { scope input, element 1 = input }
     I/O Units，即kAudioUnitType_Output：
     1、element 1的scope output是writable，element 0的scope input也是writable
     2、element 1的scope input连接麦克风，unwritable；element 0的scope output连接扬声器，unwritable
     3、每个element可以包含多种scope
     */
    AudioStreamBasicDescription audioStreamBD = NonInterleavedPCM_ASBD(_sampleRate, kAudioFormatFlagsNativeFloatPacked, sizeof(Float32), _channel);
    
    //所以下面两个设置是等价的
    AudioUnit ioUnit = [self getAudioUnit:_ioNode errorMSG:@"Could not get outputUnit in AUGraph"];
    VerifyStatus(AudioUnitSetProperty(ioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &audioStreamBD, sizeof(audioStreamBD)), @"Could not set Stream Format for I/O Units Output scope", YES);
//    AudioUnitSetProperty(ioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &audioStreamBD, sizeof(audioStreamBD));
    
    AudioFormatFlags formatFlags = kAudioFormatFlagIsPacked;
    UInt32 size = sizeof(SInt16);
    switch (_sampleFormat) {
        case AUDIO_SAMPLE_FMT_S16:
            formatFlags |= kAudioFormatFlagIsSignedInteger;
            size = sizeof(SInt16);
            break;
        default:
            break;
    }
    AudioStreamBasicDescription formatStreamBD = InterleavedPCM_ASBD(_sampleRate, formatFlags, size, _channel);    //SInt16(signed short)    16-bit signed integer
    AURenderCallbackStruct callbackStruct = {
        &RenderCallback,
        (__bridge void * _Nullable)self,
    };
    
    //设置音频格式输出格式。(应与扬声器输出格式一致)
    AudioUnit formatUnit = [self getAudioUnit:_formatNode errorMSG:@"Could not get inputUnit in AUGraph"];
    VerifyStatus(AudioUnitSetProperty(formatUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &audioStreamBD, sizeof(audioStreamBD)), @"Could not set Stream Format for AUConverter Units Output scope", YES);
    
    VerifyStatus(AudioUnitSetProperty(formatUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &formatStreamBD, sizeof(formatStreamBD)), @"Could not set Stream Format for AUConverter Units Input scope", YES);
    
    VerifyStatus(AudioUnitSetProperty(formatUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &callbackStruct, sizeof(callbackStruct)), @"Could not set AURenderCallbackStruct on formatUnit", YES);
    
    /*
     inSourceOutputNumber、inDestInputNumber即可表示输入总线(input Bus),也可以表示输出总线(output Bus)；
     指定关系可以为：
        input Bus —> output Bus,
        output Bus —> input Bus,
     */
    VerifyStatus(AUGraphConnectNodeInput(_auGraph, _formatNode, 0, _ioNode, 0), @"Could not connect formatNode to outputNode", YES);
}

/*
 仅音频录制功能
 */
- (void)openAudioRecord{
    //创建音频输出节点
    AudioComponentDescription ioACD = IO_ACD();
    VerifyStatus(AUGraphAddNode(_auGraph, &ioACD, &_ioNode), @"Could not add node with type is Output and subType is RemoteIO to AUGraph", YES);
    
    //创建音频格式转换节点
    AudioComponentDescription aucACD = AUC_ACD();
    VerifyStatus(AUGraphAddNode(_auGraph, &aucACD, &_formatNode), @"Could not add node with type is FormatConverter and subType is Splitter to AUGraph", YES);
    
    //创建音频混合器节点
    AudioComponentDescription mixACD = MCM_ACD();
    VerifyStatus(AUGraphAddNode(_auGraph, &mixACD, &_mixerNode), @"Could not add node with type is MixerConverter and subType is Splitter to AUGraph", YES);
    
    AUGraphOpen(_auGraph);
    AudioUnit ioUnit = [self getAudioUnit:_ioNode errorMSG:@"Could not get outputUnit in AUGraph"];
    
#pragma mark - I/O Unit
    
    /*
     默认情况下，音频I/O节点只开启扬声器。
     这里也开启麦克风
     */
    UInt32 enabledMicrophone = 1;
    VerifyStatus(AudioUnitSetProperty(ioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &enabledMicrophone, sizeof(enabledMicrophone)), @"Could not open microphone!", YES);
    
    //设置麦克风采样、量化、编码格式。
    AudioStreamBasicDescription microPhoneSBD = NonInterleavedPCM_ASBD(_sampleRate, kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked, sizeof(SInt32), _channel);
    VerifyStatus(AudioUnitSetProperty(ioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &microPhoneSBD, sizeof(microPhoneSBD)), @"Could not set Stream Format for I/O Units Output scope", YES);
    
    //设置音频I/O节点扬声器请求数据的最大帧数。
    UInt32 maximumFrames = 2048;
    VerifyStatus(AudioUnitSetProperty(ioUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &maximumFrames, sizeof(maximumFrames)), @"Could not set maximum Frames for I/O Units global scope", YES);

    //设置扬声器输入格式。
    AudioStreamBasicDescription speakerSBD = NonInterleavedPCM_ASBD(_sampleRate, kAudioFormatFlagsNativeFloatPacked, sizeof(Float32), _channel);
    VerifyStatus(AudioUnitSetProperty(ioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &speakerSBD, sizeof(speakerSBD)), @"Could not set Stream Format for I/O Units Input scope", YES);
    
#pragma mark - Mixer Unit
    //设置音频转换节点的输出格式。(这里如果需要输出到扬声器，需与扬声器输出格式一致，否则可以不一致)
    AudioUnit mixerUnit = [self getAudioUnit:_mixerNode errorMSG:@"Could not get mixerUnit in AUGraph"];
    //设置混合器可以混合多少路流
    UInt32 mixerElementCount = 1;
    AudioUnitSetProperty(mixerUnit, kAudioUnitProperty_ElementCount, kAudioUnitScope_Input, 0, &mixerElementCount, sizeof(mixerElementCount));
    //设置混合器输出采样率
    VerifyStatus(AudioUnitSetProperty(mixerUnit, kAudioUnitProperty_SampleRate, kAudioUnitScope_Output, 0, &_sampleRate, sizeof(_sampleRate)), @"Could not set Mixer output SampleRate", YES);
    VerifyStatus(AudioUnitSetProperty(mixerUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &speakerSBD, sizeof(speakerSBD)), @"Could not set Stream Format for I/O Units Input scope", YES);
    VerifyStatus(AudioUnitSetProperty(mixerUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &speakerSBD, sizeof(speakerSBD)), @"Could not set Stream Format for I/O Units Output scope", YES);
    
#pragma mark - Format Unit
    AudioUnit formatUnit = [self getAudioUnit:_formatNode errorMSG:@"Could not get formatUnit in AUGraph"];
    VerifyStatus(AudioUnitSetProperty(formatUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &speakerSBD, sizeof(speakerSBD)), @"Could not set Stream Format for I/O Units Input scope", YES);
    //设置音频转换节点的输入格式。(应与麦克风格式一致)
    VerifyStatus(AudioUnitSetProperty(formatUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &microPhoneSBD, sizeof(microPhoneSBD)), @"Could not set Stream Format for I/O Units Input scope", YES);
    
    /*
     麦克风->音频I/O节点Input Scope->音频转换格式节点Output Scope->音频混合器节点Output Scope
     */
    VerifyStatus(AUGraphConnectNodeInput(_auGraph, _ioNode, 1, _formatNode, 0), @"Could not connect ioNode to formatNode", YES);
    VerifyStatus(AUGraphConnectNodeInput(_auGraph, _formatNode, 0, _mixerNode, 0), @"Could not connect formatNode to mixerNode", YES);
//    VerifyStatus(AUGraphConnectNodeInput(_auGraph, _mixerNode, 0, _ioNode, 0), @"Could not connect formatNode to mixerNode", YES);  //自动填充(这种方式已形成完整的闭合节点连接了，无需在回调中填充数据)
    
    //手动填充方式，需在回调中填充_ioNode需要的数据
    AURenderCallbackStruct callbackStruct = {
        &AU_RenderCallback,
        (__bridge void * _Nullable)self
    };
    if (AudioSession.shareInstance.userSpeaker) {
        VerifyStatus(AudioUnitSetProperty(ioUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &callbackStruct, sizeof(callbackStruct)), @"Could not set AURenderCallbackStruct on formatUnit", YES);    //第二种回调方式[耳返效果貌似没有]
    }else{
        VerifyStatus(AUGraphSetNodeInputCallback(_auGraph, _ioNode, 0, &callbackStruct), @"Could not set callBack for ioNode", YES);    //第一种回调方式
    }
}

- (void)openAudioEncode:(NSString *)filePath{
    _PCMFileHandle = [NSFileHandle fileHandleForReadingAtPath:filePath];
    if (!_PCMFileHandle) {
        NSLog(@"Could not found the file with %@",filePath);
        return;
    }
    
    [self initialFilePath];
    if (!_encodeFileHandle) {
        return;
    }
    
    AudioStreamBasicDescription inputASBD = InterleavedPCM_ASBD(_sampleRate, kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked, sizeof(SInt16), _channel);
    
    AudioStreamBasicDescription outputASBD = MPEG4AAC_ASBD(inputASBD.mSampleRate, inputASBD.mChannelsPerFrame);
    
    OSType mType = kAudioFormatMPEG4AAC;
    UInt32 sizeOfMPEG4AAC = 0;
    //首先根据音频数据格式匹配系统已内置的所有编码器的总大小[这里获取所有具有MPEG4AAC编码的编码器总大小]
    VerifyStatus(AudioFormatGetPropertyInfo(kAudioFormatProperty_Encoders, sizeof(mType), &mType, &sizeOfMPEG4AAC), @"Occur an error when get Audio Format Property info", NO);
    
    if (!sizeOfMPEG4AAC) {
        return;
    }
    
    //具有MPEG4AAC编码的编码器个数
    UInt32 countOfMPEG4AAC = sizeOfMPEG4AAC / sizeof(AudioClassDescription);
    AudioClassDescription acds[countOfMPEG4AAC];
    VerifyStatus(AudioFormatGetProperty(kAudioFormatProperty_Encoders, sizeof(mType), &mType, &sizeOfMPEG4AAC, acds), @"Fail to Get Audio Format Property", NO);
    
    AudioClassDescription acd;
    for (UInt32 i = 0; i < countOfMPEG4AAC; i++) {
        AudioClassDescription tempACD = acds[i];
        
        /*
         需要的编码器具备：
            1、具有MPEG4AAC编码功能
            2、具有软件加速的
         */
        if (tempACD.mSubType == mType && tempACD.mManufacturer == kAppleSoftwareAudioCodecManufacturer) {
            acd = tempACD;
            break;
        }
    }
    
    VerifyStatus(AudioConverterNewSpecific(&inputASBD, &outputASBD, 1, &acd, &_converterRef), @"Counld not new Audio Converter", NO);
    
    if (!_converterRef) {
        return;
    }
    
    //设置编码器的比特率
    UInt32 bitRate = 128 * 1024;
    VerifyStatus(AudioConverterSetProperty(_converterRef, kAudioConverterEncodeBitRate, sizeof(bitRate), &bitRate), @"Fail to set bit rate to Encoder", NO);
    
    //获取编码器编码时每个压缩包最大需要的字节缓冲区
    UInt32 packetSizeof = sizeof(_packetSize);
    AudioConverterGetProperty(_converterRef, kAudioConverterPropertyMaximumOutputPacketSize, &packetSizeof, &_packetSize);
    
    _packetBuffer = calloc(1, _packetSize * sizeof(uint8_t));
    _encodeStatus = Audio_Encode_Opened;
}

/*
 设置保存本地文件参数设置
 */
- (void)openExtAudioFile:(NSString *)filePath{
    CFURLRef urlRef = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, (CFStringRef)filePath, kCFURLPOSIXPathStyle, false);
    
    //写入文件的ASBD
    AudioStreamBasicDescription outputSBD = InterleavedPCM_ASBD(_sampleRate, kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked, sizeof(SInt16), _channel);
    VerifyStatus(ExtAudioFileCreateWithURL(urlRef, kAudioFileCAFType, &outputSBD, NULL, kAudioFileFlags_EraseFile, &_extRef), @"Could not create Ext Audio File!", YES);
    
    CFRelease(urlRef);
    
    /*
     获取最后输出的音频节点的输出格式
     */
    AudioStreamBasicDescription inputSBD;
    UInt32 asdbSize = sizeof(inputSBD);
    memset(&inputSBD, 0, asdbSize);
    AudioUnit mixerUnit = [self getAudioUnit:_mixerNode errorMSG:@"Could not get formatUnit in AUGraph"];
    VerifyStatus(AudioUnitGetProperty(mixerUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &inputSBD, &asdbSize), @"Could not get ASBD from formatUnit", YES);
    
    //将音频输出节点格式设置到文件流的输入格式
    VerifyStatus(ExtAudioFileSetProperty(_extRef, kExtAudioFileProperty_ClientDataFormat, sizeof(inputSBD), &inputSBD), @"Could bind ASBD to Ext Audio File", YES);
    
    //指定使用硬件编码
    UInt32 codecStyle = kAppleHardwareAudioCodecManufacturer;
    VerifyStatus(ExtAudioFileSetProperty(_extRef, kExtAudioFileProperty_CodecManufacturer, sizeof(codecStyle), &codecStyle), @"Could Specified Audio Codec Style!", YES);
    
    //初始化异步读写器
    VerifyStatus(ExtAudioFileWriteAsync(_extRef, 0, NULL), @"Could not Initial Ext Audio File Writer!", YES);
}

/*
 音频文件播放功能
 */
- (void)openAudioPlayWithFile:(NSString *)filePath{
    //创建音频输出节点
    AudioComponentDescription ioACD = IO_ACD();
    VerifyStatus(AUGraphAddNode(_auGraph, &ioACD, &_ioNode), @"Could not add node with type is Output and subType is RemoteIO to AUGraph", YES);
    
    //创建音频文件输入节点
    AudioComponentDescription afpACD = AFP_ACD();
    VerifyStatus(AUGraphAddNode(_auGraph, &afpACD, &_fileNode), @"Could not add node with type is Generator and subType is AudioFilePlayer to AUGraph", YES);
    
    //在获取Audio Unit之前必须打开AuGraph，否则获取错误。
    AUGraphOpen(_auGraph);
    
    /*
     Generator Units，即kAudioUnitType_Generator
     1、没有音频输入have no audio input，有音频输出produce audio output
     2、所以只能设置element 0
     */
    AudioStreamBasicDescription audioStreamBD = NonInterleavedPCM_ASBD(_sampleRate, kAudioFormatFlagsNativeFloatPacked, sizeof(Float32), _channel);
    AudioUnit fileUint = [self getAudioUnit:_fileNode errorMSG:@"Could not get inputUnit in AUGraph"];
    VerifyStatus(AudioUnitSetProperty(fileUint, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &audioStreamBD, sizeof(audioStreamBD)), @"Could not set Stream Format for Generator Units Output scope", YES);
    
    //连接节点
    VerifyStatus(AUGraphConnectNodeInput(_auGraph, _fileNode, 0, _ioNode, 0), @"Could not connect inputNode to outputNode", YES);
}

/*
 设置播放本地文件参数设置
 */
- (void)openAudioFileRegion:(NSString *)filePath{
    NSURL *tempPath = [NSURL URLWithString:filePath];
    AudioUnit inputUnit = [self getAudioUnit:_fileNode errorMSG:@"Could not get inputUnit in AUGraph"];
    
    /*
     获取文件句柄
     */
    AudioFileID fileID;
    VerifyStatus(AudioFileOpenURL((__bridge CFURLRef)tempPath, kAudioFileReadPermission, 0, &fileID), [NSString stringWithFormat:@"Could not open file with %@",filePath], YES);
    
    /*
     根据文件句柄获取文件的格式信息、总的编码包Packet的数量。
     */
    AudioStreamBasicDescription audioStreamBD;
    UInt32 structSize = sizeof(audioStreamBD);
    memset(&audioStreamBD, 0, structSize);
    VerifyStatus(AudioFileGetProperty(fileID, kAudioFilePropertyDataFormat, &structSize, &audioStreamBD), @"Could not get file Stream Basic Description", YES);
    
    UInt64 packetCount;
    UInt32 countTypeOfSize = sizeof(packetCount);
    VerifyStatus(AudioFileGetProperty(fileID, kAudioFilePropertyAudioDataPacketCount, &countTypeOfSize, &packetCount), @"Could not get file packet count", YES);
    
    /*
     将文件句柄绑定的Generator Units
     */
    VerifyStatus(AudioUnitSetProperty(inputUnit, kAudioUnitProperty_ScheduledFileIDs, kAudioUnitScope_Global, 0, &fileID, sizeof(fileID)), @"Could not bind file to input Unit", YES);
    
    ScheduledAudioFileRegion fileRegion;
    fileRegion.mTimeStamp.mFlags = kAudioTimeStampSampleTimeValid;
    fileRegion.mTimeStamp.mSampleTime = 0;
    fileRegion.mCompletionProc = NULL;
    fileRegion.mCompletionProcUserData = NULL;
    fileRegion.mAudioFile = fileID;
    fileRegion.mLoopCount = 0;
    fileRegion.mStartFrame = 0; //拖动[Seek]操作就是在这里设置的
    fileRegion.mFramesToPlay = (UInt32)packetCount * audioStreamBD.mFramesPerPacket;
    VerifyStatus(AudioUnitSetProperty(inputUnit, kAudioUnitProperty_ScheduledFileRegion, kAudioUnitScope_Global, 0, &fileRegion, sizeof(fileRegion)), @"Could not set File Region to input Unit", YES);
    
    //设置Generator Units开始时间。
    AudioTimeStamp timeStamp;
    memset (&timeStamp, 0, sizeof(timeStamp));
    timeStamp.mFlags = kAudioTimeStampSampleTimeValid;
    timeStamp.mSampleTime = -1;
    VerifyStatus(AudioUnitSetProperty(inputUnit, kAudioUnitProperty_ScheduleStartTimeStamp,
                                      kAudioUnitScope_Global, 0, &timeStamp, sizeof(timeStamp)), @"Could not set File Region to time Stamp", YES);
}

- (AudioUnit)getAudioUnit:(AUNode)node errorMSG:(NSString *)errorMSG{
    AudioUnit audioUnit = NULL;
    VerifyStatus(AUGraphNodeInfo(_auGraph, node, NULL, &audioUnit), errorMSG, YES);
    return audioUnit;
}

/*
 1、音频所需数据是存放在 AudioBufferList 中的 mBuffers 数组中。
 2、如果音频流音频描述的 mFormatFlags 为NonInterleaved，则左声道在 mBuffers[0]，右声道在 mBuffers[1]；
    若mFormatFlags 为Interleaved，则左右声道数据交错存储在 mBuffers[0]。
 */
- (OSStatus)renderCallback:(const AudioTimeStamp *)inTimeStamp inBusNumber:(UInt32)inBusNumber inNumberFrames:(UInt32)inNumberFrames ioData:(AudioBufferList *)ioData
{
    for (UInt32 i = 0; i < ioData->mNumberBuffers; i++) {
        AudioBuffer buffer = ioData->mBuffers[i];
        memset(buffer.mData, 0, buffer.mDataByteSize);  //重置内存空间
    }
    
    if (_playStatus == Audio_Play_Closed) {
        return noErr;
    }
    
    /*
     音频刚开始启动时，回调这个方法的时候音频表还有可能未完全启动起来。[否则会造成自定义的信号量死锁]
     这种情况说明AUGraphStart状态还未回调。
     */
    Boolean isRuning;
    VerifyStatus(AUGraphIsRunning(_auGraph, &isRuning), @"Could not get AUGraph status", YES);
    if (!isRuning) {
        return noErr;
    }
    
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    if (_playStatus == Audio_Play_Closed) {
        dispatch_semaphore_signal(_semaphore);
        return noErr;
    }
    
    for (UInt32 i = 0; i < ioData->mNumberBuffers; i++) {
        AudioBuffer buffer = ioData->mBuffers[i];
        if (_bufferSize < buffer.mDataByteSize) {
            _bufferData = realloc(_bufferData, buffer.mDataByteSize - _bufferSize);
            memset(_bufferData, 0, buffer.mDataByteSize - _bufferSize);
            _bufferSize = buffer.mDataByteSize;
        }
        
        ![self.delegate respondsToSelector:@selector(retrieveCallback:numberFrames:numberChannels:)] ? : [self.delegate retrieveCallback:_bufferData numberFrames:inNumberFrames numberChannels:_channel];
        
        memcpy(ioData->mBuffers[i].mData, _bufferData, ioData->mBuffers[i].mDataByteSize);
    }
    dispatch_semaphore_signal(_semaphore);
    
    return noErr;
}

- (OSStatus)auRenderCallback:(AudioUnitRenderActionFlags *)ioActionFlags inTimeStamp:(const AudioTimeStamp *)inTimeStamp inBusNumber:(UInt32)inBusNumber inNumberFrames:(UInt32)inNumberFrames ioData:(AudioBufferList *)ioData
{
    OSStatus status = noErr;
    if (_playStatus == Audio_Play_Closed) {
        return status;
    }
    
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    if (_playStatus == Audio_Play_Closed) {
        dispatch_semaphore_signal(_semaphore);
        return status;
    }
    
    AudioUnit mixerUnit = [self getAudioUnit:_mixerNode errorMSG:@"Could not get mixerNode in AUGraph"];
    VerifyStatus(AudioUnitRender(mixerUnit, ioActionFlags, inTimeStamp, 0, inNumberFrames, ioData), @"AURender fail!", YES);
    status = ExtAudioFileWriteAsync(_extRef, inNumberFrames, ioData);
    
    if (AudioSession.shareInstance.userSpeaker) {
        for (UInt32 i = 0; i < ioData->mNumberBuffers; i++) {
            AudioBuffer buffer = ioData->mBuffers[i];
            memset(buffer.mData, 0, buffer.mDataByteSize);  //重置内存空间
        }
    }
    
    dispatch_semaphore_signal(_semaphore);
    
    return status;
}

- (OSStatus)inInputDataProc:(AudioConverterRef)inAudioConverter ioNumberDataPackets:(UInt32 *)ioNumberDataPackets ioData:(AudioBufferList *)ioData
{
    UInt32 numberOfPackets = *ioNumberDataPackets;
    /*
     总数据包大小 = 数据包个数 * 频道数 * 量化格式大小.
     PS：因为输入的PCM数据是交错型存储的
     */
    UInt32 PCMBufferSize = numberOfPackets * _channel * sizeof(SInt16);
    if (_PCMBufferSize < PCMBufferSize) {
        _PCMBuffer = realloc(_PCMBuffer, PCMBufferSize - _PCMBufferSize);
        memset(_PCMBuffer, 0, PCMBufferSize - _PCMBufferSize);
        _PCMBufferSize = PCMBufferSize;
    }
    
    /*
     If your callback returns an error, it must return zero packets of data.
     */
    NSData *data = [_PCMFileHandle readDataOfLength:PCMBufferSize];
    if (data.length <= 0) {
        *ioNumberDataPackets = 0;
        return -1;
    }
    
    memcpy(_PCMBuffer, data.bytes, data.length);
    ioData->mBuffers[0].mDataByteSize = (UInt32)data.length;
    ioData->mBuffers[0].mData = _PCMBuffer;
    *ioNumberDataPackets = 1 ;
    
    return noErr;
}

/*
 @param filePath    You should set the field when use Audio_PlayWithFile_Type.
 */
- (void)startAudio:(AudioPlayType)playType filePath:(NSString *_Nullable)filePath
{
    HasAuthorization(AVMediaTypeAudio, ^(BOOL granted) {
        !granted ? : dispatch_async(self.dispatchQueue, ^
        {
            dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
            switch (self.playStatus) {
                case Audio_Play_Opened:
                    dispatch_semaphore_signal(self.semaphore);
                    return;
                case Audio_Play_UnOpen:
                case Audio_Play_Closed:
                    [self openAudio:playType filePath:filePath];
                    break;
                default:
                    break;
            }
            
            Boolean isRuning;
            VerifyStatus(AUGraphIsRunning(self->_auGraph, &isRuning), @"Could not get AUGraph status", YES);
            
            Boolean isInitial = false;
            isRuning ? : VerifyStatus(AUGraphIsInitialized(self->_auGraph, &isInitial), @"Could not Initialized AUGraph", NO);
            
            /*
             any activities that affect the state of the graph are guarded with locks
             任意会影响音频表对象的状态的行为都会被加锁。
             */
            !isInitial ? : VerifyStatus(AUGraphStart(self->_auGraph), @"Could not start AUGraph", NO);
            
            dispatch_semaphore_signal(self.semaphore);
        });
    });
}

- (void)restartAudioEncode:(NSString *)filePath{
    _encodeStatus = Audio_Encode_UnOpen;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self startAudioEncode:filePath];
    });
}

- (void)startAudioEncode:(NSString *)filePath{
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    switch (_encodeStatus) {
        case Audio_Encode_Opened:   //防止重复开启音频编码
        case Audio_Encode_Closed:   //已关闭后只能重新开启restart
            dispatch_semaphore_signal(_semaphore);
            return;
        case Audio_Encode_UnOpen:
            [self openAudio:Audio_Encode_Type filePath:filePath];
            break;
        default:
            break;
    }
    dispatch_semaphore_signal(_semaphore);
    
    if (_encodeStatus != Audio_Encode_Opened) {
        return;
    }
    
    while (true) {
        dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
        if (_encodeStatus != Audio_Encode_Opened) {
            dispatch_semaphore_signal(_semaphore);
            break;
        }
        
        /*
         On input:解码；On output:编码。
         */
        AudioBufferList packetBufferList = {1};
        packetBufferList.mBuffers[0].mNumberChannels = _channel;
        packetBufferList.mBuffers[0].mDataByteSize = _packetSize;
        packetBufferList.mBuffers[0].mData = _packetBuffer;
        UInt32 ioOutputDataPacketSize = 1;  //这里属于On output情况，写入到packetBufferList的已转换的音频数据包的个数
        VerifyStatus(AudioConverterFillComplexBuffer(_converterRef, InInputDataProc, (__bridge void *)self, &ioOutputDataPacketSize, &packetBufferList, NULL), @"Could not exec Audio Converter Fill ComplexBuffer or Completed!", NO);
        
        if (!packetBufferList.mBuffers[0].mDataByteSize) {
            dispatch_semaphore_signal(_semaphore);
            [self closeAudioPaly];
            break;
        }
        
        NSData *pcmEncodeData = [NSData dataWithBytes:_packetBuffer length:packetBufferList.mBuffers[0].mDataByteSize];
        NSData *adtsData = [self appendADTSWithPakcetLength:pcmEncodeData.length];
        NSMutableData *completeData = [NSMutableData dataWithData:adtsData];
        [completeData appendData:pcmEncodeData];
        
        [_encodeFileHandle writeData:completeData];
        dispatch_semaphore_signal(_semaphore);
    }
}

- (NSData *)appendADTSWithPakcetLength:(NSUInteger)length{
    size_t adtsLength = 7;
    size_t sumLength = adtsLength + length;
    uint8_t profile = 2;    //kMPEG4Object_AAC_LC
    uint8_t sampleIndex = 4;    //44.1KHz
    uint8_t channelConfig = _channel;   //声道配置

    uint8_t *adtsData = calloc(1, adtsLength * sizeof(uint8_t));
    adtsData[0] = 0xFF; //syncword
    adtsData[1] = 0xF9; //syncword MPEG-2 Layer CRC
    adtsData[2] = ((profile - 1) << 6) + (sampleIndex << 2) + (channelConfig >> 2);
    adtsData[3] = ((channelConfig & 3) << 6) + (sumLength >> 11);
    adtsData[4] = (sumLength & 0x07FF) >> 3;
    adtsData[5] = ((sumLength & 7) << 5) + 0x1F;
    adtsData[6] = 0xFC;

    return [NSData dataWithBytesNoCopy:adtsData length:adtsLength];
}

- (void)pauseAudioPaly{
    _playStatus = Audio_Play_Paused;
    VerifyStatus(AUGraphStop(self->_auGraph), @"Could not pause AUGraph", NO);
}

- (void)closeAudioPaly{
    //已关闭直接返回
    if (_playStatus == Audio_Play_Closed) {
        return;
    }
    
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    //设置正在关闭状态
    _playStatus = Audio_Play_Closed;
    _encodeStatus = Audio_Encode_Closed;
    
    Boolean isRuning = NO;
    !_auGraph ? : VerifyStatus(AUGraphIsRunning(_auGraph, &isRuning), @"Could not get AUGraph status", YES);
    if (isRuning) {
        VerifyStatus(AUGraphStop(_auGraph), @"Could not stop AUGraph", YES);
        VerifyStatus(AUGraphUninitialize(_auGraph), @"Could not cancle initialize AUGraph", YES);
        VerifyStatus(AUGraphClose(_auGraph), @"Could not Close AUGraph", YES);
        !_ioNode ? : VerifyStatus(AUGraphRemoveNode(_auGraph, _ioNode), @"Could not remove ioNode", YES);
        !_fileNode ? : VerifyStatus(AUGraphRemoveNode(_auGraph, _fileNode), @"Could not remove fileNode", YES);
        !_formatNode ? : VerifyStatus(AUGraphRemoveNode(_auGraph, _formatNode), @"Could not remove formatNode", YES);
        !_mixerNode ? : VerifyStatus(AUGraphRemoveNode(_auGraph, _mixerNode), @"Could not remove mixerNode", YES);
        !_extRef ? : VerifyStatus(ExtAudioFileDispose(_extRef), @"Could not Dispose Ext Audio File", YES);
        !_converterRef ? : VerifyStatus(AudioConverterDispose(_converterRef), @"Could not Dispose Audio Converter", YES);
        VerifyStatus(DisposeAUGraph(_auGraph), @"Could not Dispose AUGraph", YES);
    }
    [_encodeFileHandle closeFile];
    [_PCMFileHandle closeFile];
    
    !_packetBuffer ? : free(_packetBuffer);
    !_bufferData ? : free(_bufferData);
    !_PCMBuffer ? : free(_PCMBuffer);
    _packetBuffer = NULL;
    _bufferData = NULL;
    _PCMBuffer = NULL;
    _PCMBufferSize = 0;
    _packetSize = 0;
    _bufferSize = 0;
    _ioNode = 0;
    _fileNode = 0;
    _formatNode = 0;
    _mixerNode = 0;
    
    dispatch_semaphore_signal(_semaphore);
    NSLog(@"Close AudioPaly success!");
}

#pragma mark - 临时处理

- (void)initialFilePath{
    NSString *filePath = InCachesDirectory(@"Record");
    if (![NSFileManager.defaultManager fileExistsAtPath:filePath]) {
        NSError *error = nil;
        if (![NSFileManager.defaultManager createDirectoryAtPath:filePath withIntermediateDirectories:NO attributes:nil error:&error]) {
            NSLog(@"Attempt to Create a Director or file fail while begin to encode preview!");
            return;
        }
    }
    
    filePath = [filePath stringByAppendingFormat:@"/%@.aac",NSDate.date.formatToString];
    if (![NSFileManager.defaultManager createFileAtPath:filePath contents:nil attributes:nil]) {
        NSLog(@"Attempt to Create a Director or file fail while begin to encode preview!");
        return;
    }
    
    _encodeFileHandle = [NSFileHandle fileHandleForWritingAtPath:filePath];
    if (!_encodeFileHandle) {
        NSLog(@"Attempt to Create a Director or file fail while begin to encode preview!");
        return;
    }
}

@end

static OSStatus RenderCallback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData)
{
    AudioPlay *audioPlay = (__bridge AudioPlay *)inRefCon;
    return [audioPlay renderCallback:inTimeStamp inBusNumber:inBusNumber inNumberFrames:inNumberFrames ioData:ioData];
}

static OSStatus AU_RenderCallback(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData)
{
    AudioPlay *audioPlay = (__bridge AudioPlay *)inRefCon;
    return [audioPlay auRenderCallback:ioActionFlags inTimeStamp:inTimeStamp inBusNumber:inBusNumber inNumberFrames:inNumberFrames ioData:ioData];
}

static OSStatus InInputDataProc(AudioConverterRef inAudioConverter, UInt32 *ioNumberDataPackets, AudioBufferList *ioData, AudioStreamPacketDescription * _Nullable *outDataPacketDescription, void *inUserData)
{
    AudioPlay *audioPlay = (__bridge AudioPlay *)inUserData;
    return [audioPlay inInputDataProc:inAudioConverter ioNumberDataPackets:ioNumberDataPackets ioData:ioData];
}
