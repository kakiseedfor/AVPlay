//
//  EncodeController.m
//  AVPlay
//
//  Created by kakiYen on 2019/11/11.
//  Copyright © 2019 kakiYen. All rights reserved.
//

#import "VTEncodeSession.h"
#import "CommonUtility.h"
#import "NSDate+String.h"

/*
 H.264视频编码格式:
    ◆H.264码流：
        *AVCC：MPEG-4格式，也叫AVC格式，属于字节流格式[Bytes-Stream Format],
            常用于mp4/flv/mkv等封装格式、VideoToolbox。
        *Annex-B：MPEG-2格式，属于简单流格式[Elementary Stream(ES)]。
 
    ◆H.264 Annex-B码流结构：
        H.264由多个NALU[NetWork Abstracttion Layer Uint]，按顺序一个接一个组成。
            [StartCode + NALU] + [StartCode + NALU] + [StartCode + NALU] + [StartCode + NALU]......
 
        NALU = NAL头 + RBSP。
            =>[StartCode + [NAL头 + RBSP]] + [StartCode + [NAL头 + RBSP]] + [StartCode + [NAL头 + RBSP]]......
 
        RBSP原始字节序列负载量[Raw Bytes Sequence Payload], 可能是Slice(片)、SPS、PPS、IDR;
            =>[StartCode + [NAL头 + SPS]] + [StartCode + [NAL头 + PPS]] + [StartCode + [NAL头 + Slice(IDR)]] + [StartCode + [NAL头 + Slice(P)]] + [StartCode + [NAL头 + Slice(B)]]......
 
        一帧[Frame] = [StartCode + [NAL头 + Slice]] (+ [StartCode + [NAL头 + Slice]] + [StartCode + [NAL头 + Slice]]...)
 
        Slice(片) = 片头 + 宏[Macroblock] (+ 宏[Macroblock] + 宏[Macroblock]......)。
        宏[Macroblock] = 宏块类型 + 预测类型 + CPB[Coded Block Pattern] + QP[Quantization Parameter] + 宏块数据
            I片：只包含I宏块，在当前片内进行帧内预测(不参考其他片中的宏块)。
            P片：包含P宏块(+I宏块)，P宏块利用前面的一帧做帧内预测。[可以做子宏块的切割]
            B片：包含B宏块(+I宏块)，B宏块利用前面的一帧或两帧做双向帧内预测，
            SP片：包含P宏块(+I宏块)，可以让你在编码流中切换。
            SI片：由特殊的SI宏块组成，可以让你在编码流中切换。
 
    ◆H.264 AVCC码流结构：
        =>[Extradata + NALU.length + NALU] + [NALU.length + NALU] + [NALU.length + NALU]......
        =>[Extradata + NALU.length + [NAL头 + Slice(IDR)]] + [NALU.length + [NAL头 + Slice(P)]] + [NALU.length + [NAL头 + Slice(B)]]...
 
        Extradata：包含NALU长度[SPS、PPS]。
        | a |     b     | c | d |   e   |       F       | g |   h   |    I      |                j               |
        -------------------------------------------------------------------------------------------------------------
        | 8 |     24    | 8 | 8 |   16  |      SPS      | 8 |   16  |   PPS     |            NALU.length         |
        -------------------------------------------------------------------------------------------------------------
            a：版本信息，固定0x01。
            b：配合c中的 Bit0-1来选择字节数。
            c：预留Bit2-7[bit on]，Bit0-1[NALU字节数所占字节 - 1]，一般为0、1、3。
            d：预留Bit5-7[bit on]，Bit0-4[多少个SPS，通常为1]。
            e：SPS所占字节数。[小大端存储]
            F：SPS的数据。
            g：预留Bit5-7[bit on]，Bit0-4[多少个PPS，通常为1]。
            h：PPS所占字节数。[小大端存储]
            I：PPS的数据。
            j：NALU字节数所占字节。[不包含在Extradata中]
            ⚠️e~F至少一次，h~I至少一次。
 */

#define Compression_FPS 24.f
#define Compression_MaxBitRate 720 * 1280
#define Compression_AVGBitRate 360 * 640

void (CompressionOutputCallback)(void *outputCallbackRefCon, void *sourceFrameRefCon, OSStatus status, VTEncodeInfoFlags infoFlags, CMSampleBufferRef sampleBuffer);

@interface VTEncodeSession (){
    VTCompressionSessionRef _compressionSessionRef;
}
@property (strong, nonatomic) dispatch_semaphore_t semaphore;
@property (strong, nonatomic) dispatch_queue_t dispatchQueue;
@property (strong, nonatomic) NSFileHandle *fileHandle;
@property (nonatomic) CMTimeValue timeMillions;
@property (nonatomic) VTEncodeStatus status;

@end

@implementation VTEncodeSession

- (void)dealloc
{
    NSLog(@"%s",__FUNCTION__);
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _status = UnOpenVTEncode;
        _semaphore = dispatch_semaphore_create(1);
        _dispatchQueue = dispatch_queue_create("VTEncodeSession.Queue", NULL);
    }
    return self;
}

- (void)initialFilePath{
    NSString *filePath = InCachesDirectory(@"Record");
    if (![NSFileManager.defaultManager fileExistsAtPath:filePath]) {
        NSError *error = nil;
        if (![NSFileManager.defaultManager createDirectoryAtPath:filePath withIntermediateDirectories:NO attributes:nil error:&error]) {
            NSLog(@"Attempt to Create a Director or file fail while begin to encode preview!");
            return;
        }
    }
    
    filePath = [filePath stringByAppendingFormat:@"/%@.h264",NSDate.date.formatToString];
    if (![NSFileManager.defaultManager createFileAtPath:filePath contents:nil attributes:nil]) {
        NSLog(@"Attempt to Create a Director or file fail while begin to encode preview!");
        return;
    }
    
    _fileHandle = [NSFileHandle fileHandleForWritingAtPath:filePath];
    if (!_fileHandle) {
        NSLog(@"Attempt to Create a Director or file fail while begin to encode preview!");
        return;
    }
    
    _status = OpenedVTEncode;
}

- (void)initialSession:(int32_t)pixelWidth height:(int32_t)pixelHeight{
    VerifyStatus(VTCompressionSessionCreate(kCFAllocatorDefault, pixelWidth, pixelHeight, kCMVideoCodecType_H264, NULL, NULL, kCFAllocatorDefault, CompressionOutputCallback, (__bridge void * _Nullable)(self), &_compressionSessionRef), @"Occur an error when create CompressionSession!", YES);
    
    VerifyStatus(VTSessionSetProperty(_compressionSessionRef, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue), @"Error while you set some Property for CompressionSession!", YES);   //实时进行压缩
    VerifyStatus(VTSessionSetProperty(_compressionSessionRef, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_High_AutoLevel), @"Error while you set some Property for CompressionSession!", YES);  //H264的规格描述
    VerifyStatus(VTSessionSetProperty(_compressionSessionRef, kVTCompressionPropertyKey_AllowFrameReordering, kCFBooleanFalse), @"Error while you set some Property for CompressionSession!", YES);  //取消B帧
    VerifyStatus(VTSessionSetProperty(_compressionSessionRef, kVTCompressionPropertyKey_MaxKeyFrameInterval, (__bridge CFTypeRef _Nullable)(@(24.f))), @"Error while you set some Property for CompressionSession!", YES);   //GOP 大小
    VerifyStatus(VTSessionSetProperty(_compressionSessionRef, kVTCompressionPropertyKey_ExpectedFrameRate, (__bridge CFTypeRef _Nullable)(@(24.f))), @"Error while you set some Property for CompressionSession!", YES); //视频帧率
    VerifyStatus(VTSessionSetProperty(_compressionSessionRef, kVTCompressionPropertyKey_DataRateLimits, (__bridge CFTypeRef _Nullable)@[@(Compression_MaxBitRate / 8) , @1.f]), @"Error while you set some Property for CompressionSession!", YES); //编码最大码率限制
    VerifyStatus(VTSessionSetProperty(_compressionSessionRef, kVTCompressionPropertyKey_AverageBitRate, (__bridge CFTypeRef _Nullable)@(Compression_AVGBitRate)), @"Error while you set some Property for CompressionSession!", YES);    //编码平均码率
    /*
     没有调用这个方法，后面第一次开始编码的时候，会自动初始化编码需要的设置
     */
    VerifyStatus(VTCompressionSessionPrepareToEncodeFrames(_compressionSessionRef), @"Error, could not prepare Compression Session!", YES);
    
    [self initialFilePath];
}

- (void)startEncodFrame:(CMSampleBufferRef)sampleBuffer{
    if (!sampleBuffer) {
        return;
    }
    
    CMSampleTimingInfo timingInfo = kCMTimingInfoInvalid;
    VerifyStatus(CMSampleBufferGetSampleTimingInfo(sampleBuffer, 0, &timingInfo), @"Occur an error when you try to get Sample Timing Info!", YES);
    
    if (!_timeMillions) {
        _timeMillions = timingInfo.presentationTimeStamp.value;
    }
    //计算每帧显示时间
    CMTime pts = CMTimeMake(timingInfo.presentationTimeStamp.value - _timeMillions, 1000);
    
    VTEncodeInfoFlags infoFlags = kVTEncodeInfo_Asynchronous;
    VerifyStatus(VTCompressionSessionEncodeFrame(_compressionSessionRef, CMSampleBufferGetImageBuffer(sampleBuffer), pts, CMTimeMake(1, Compression_FPS), NULL, NULL, &infoFlags), @"Compression Session Encode fail!", NO);
}

- (void)startEncoderSession:(CMSampleBufferRef)sampleBuffer{
    dispatch_async(_dispatchQueue, ^{
        if (self.status == ClosedVTEncode) {
            return ;
        }
        dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
        switch (self.status) {
            case ClosedVTEncode:{
                dispatch_semaphore_signal(self.semaphore);
                return;
            }
                break;
            case UnOpenVTEncode:{
                CMFormatDescriptionRef formatDes = CMSampleBufferGetFormatDescription(sampleBuffer);
                CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(formatDes);
                [self initialSession:dimensions.width height:dimensions.height];
            }
                break;
            default:
                break;
        }
        
        if (self.status != OpenedVTEncode) {
            dispatch_semaphore_signal(self.semaphore);
            return;
        }
        
        [self startEncodFrame:sampleBuffer];
        dispatch_semaphore_signal(self.semaphore);
    });
}

- (void)closeEncoderSession{
    if (_status != OpenedVTEncode) {
        return;
    }
    
    _status = ClosedVTEncode;
    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);
    
    /*
     丢弃未编码完成的Frame
     */
    VerifyStatus(VTCompressionSessionCompleteFrames(_compressionSessionRef, kCMTimeInvalid), @"Couldn't End Complete Session!", YES);
    VTCompressionSessionInvalidate(_compressionSessionRef);
    CFRelease(_compressionSessionRef);
    dispatch_semaphore_signal(_semaphore);
    
    NSLog(@"Close EncoderSession success!");
}

- (void)writeHeaderDataToFile:(NSData *)spsData ppsData:(NSData *)ppsData{
    NSUInteger startCodeLength = 4;
    NSUInteger totalLength = spsData.length + ppsData.length + startCodeLength * 2;
    Byte *buffer = malloc(totalLength);
    
    const char startCode[] = "\x00\x00\x00\x01";
    memcpy(buffer, &startCode, startCodeLength);    //拼接开始码
    memcpy(buffer + startCodeLength, spsData.bytes, spsData.length);    //拼接SPS
    memcpy(buffer + startCodeLength + spsData.length, &startCode, startCodeLength); //拼接开始码
    memcpy(buffer + startCodeLength * 2 + spsData.length, ppsData.bytes, ppsData.length);   //拼接PPS
    NSData *data = [NSData dataWithBytes:buffer length:totalLength];
    [_fileHandle writeData:data];
    
    free(buffer);
}

- (void)writeContentDataToFile:(NSData *)data pts:(int64_t)pts dts:(int64_t)dts{
    NSUInteger startCodeLength = 4;
    NSUInteger totalLength = data.length + startCodeLength;
    Byte *buffer = malloc(totalLength);
    
    const char startCode[] = "\x00\x00\x00\x01";
    memcpy(buffer, &startCode, startCodeLength);    //拼接开始码
    memcpy(buffer + startCodeLength, data.bytes, data.length);    //拼接采样数据
    NSData *tempData = [NSData dataWithBytes:buffer length:totalLength];
    [_fileHandle writeData:tempData];
    
    free(buffer);
}

- (void)compressionOutputCallback:(void *)sourceFrameRefCon status:(OSStatus)status infoFlags:(VTEncodeInfoFlags)infoFlags sampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    if (status != noErr) {
        NSLog(@"It is fail to compression sampleBuffer!");
        return;
    }
    
    if (!CMSampleBufferDataIsReady(sampleBuffer)) {
        return;
    }
    
    /*
     A sync sample, also known as a key frame or IDR (Instantaneous Decoding Refresh), can be decoded without requiring any previous samples to have been decoded
     */
    CFArrayRef attachmentsRef = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, false);
    CFDictionaryRef attachmentRef = CFArrayGetValueAtIndex(attachmentsRef, 0);
    
    /*
     SampleBuffer为I帧或IDR帧的话，需要取出对应SPS和PPS
     */
    if (!CFDictionaryContainsKey(attachmentRef, kCMSampleAttachmentKey_NotSync)) {
        CMFormatDescriptionRef formatDes = CMSampleBufferGetFormatDescription(sampleBuffer);
        /*
         This function parses the AVC decoder configuration record contained in a H.264 video format description.
         分析编码器配置记录里的 H.264视频格式信息[因为创建会话的时候已指定是 kCMVideoCodecType_H264].
         */
        const uint8_t *spsParameterSetPointerOut;
        size_t spsParameterSetSizeOut, spsParameterSetCountOut;
        VerifyStatus(CMVideoFormatDescriptionGetH264ParameterSetAtIndex(formatDes, 0, &spsParameterSetPointerOut, &spsParameterSetSizeOut, &spsParameterSetCountOut, NULL), @"Fail to get H264 parameter!", NO);    //获取SPS信息。
        
        const uint8_t *ppsParameterSetPointerOut;
        size_t ppsParameterSetSizeOut, ppsParameterSetCountOut;
        VerifyStatus(CMVideoFormatDescriptionGetH264ParameterSetAtIndex(formatDes, 1, &ppsParameterSetPointerOut, &ppsParameterSetSizeOut, &ppsParameterSetCountOut, NULL), @"Fail to get H264 parameter!", NO);    //获取PPS信息。
        
        NSData *spsData = spsParameterSetPointerOut ? [NSData dataWithBytes:spsParameterSetPointerOut length:spsParameterSetSizeOut] : nil;
        NSData *ppsData = ppsParameterSetPointerOut ? [NSData dataWithBytes:ppsParameterSetPointerOut length:ppsParameterSetSizeOut] : nil;
        [self writeHeaderDataToFile:spsData ppsData:ppsData];
    }
    
    CMBlockBufferRef blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    size_t lengthAtOffsetOut, totalLengthOut;
    char *dataPointerOut = NULL;
    //获取压缩数据块的内容指针。
    if (CMBlockBufferGetDataPointer(blockBuffer, 0, &lengthAtOffsetOut, &totalLengthOut, &dataPointerOut)) {
        NSLog(@"Get block buffer data pointer fail!");
        return;
    }
    NSLog(@"--------------------------------");
    NSLog(@"total Length Out %zu",totalLengthOut);
    
    int readOffset = 0;
    static int headerOffset = 4;    //AVCC是通过使用一个固定的字节数[4个字节，存储NALU字节数]，来进行NALU分割。
    while (headerOffset +  readOffset < totalLengthOut) {   //因为一个 BlockBuffe 可能有多个NALU[尤其是IDR]，所以需要遍历。
        uint32_t headerValue = 0;
        memcpy(&headerValue, dataPointerOut + readOffset, headerOffset);
        headerValue = CFSwapInt32BigToHost(headerValue);    //大端转小端
        
        NSLog(@"header Value %u",headerValue);
        
        NSData *data = [NSData dataWithBytes:dataPointerOut + readOffset + headerOffset  length:headerValue];
        int64_t pts = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer)) * 1000.f;
        int64_t dts = pts;  //因为没有B帧，所以解码顺序与显示顺序是一样的。
        [self writeContentDataToFile:data pts:pts dts:dts];
        
        readOffset += headerValue + headerOffset;
        
        NSLog(@"read Offset %u",readOffset);
    }
}

@end

void CompressionOutputCallback(void *outputCallbackRefCon, void *sourceFrameRefCon, OSStatus status, VTEncodeInfoFlags infoFlags, CMSampleBufferRef sampleBuffer)
{
    VTEncodeSession *encodeSession = (__bridge VTEncodeSession*)outputCallbackRefCon;
    [encodeSession compressionOutputCallback:sourceFrameRefCon status:status infoFlags:infoFlags sampleBuffer:sampleBuffer];
}
