//
//  Decoder.m
//  AVPlay
//
//  Created by kakiYen on 2019/9/4.
//  Copyright © 2019 kakiYen. All rights reserved.
//

#import "libswresample/swresample.h"
#import "libavformat/avformat.h"
#import "libswscale/swscale.h"
#import "libavutil/imgutils.h"
#import <pthread.h>
#import "Decoder.h"

#define Max_Buffered_Duration 1

#define Detect_TimeOut 20

#define RetryCount 3

static int InterruptCallback(void *context);

static void * _Nullable ThreadMain(void * _Nullable arg);

typedef struct SwsContext SwsContext;

/*
 4*4图片存储方式有：
 I420: YYYY YYYY YYYY YYYY UU UU VV VV   =>  YUV420P
 YV12: YYYY YYYY YYYY YYYY VV VV UU UU   =>  YUV420P
 NV12: YYYY YYYY YYYY YYYY UVUVUVUV    =>  YUV420SP
 NV21: YYYY YYYY YYYY YYYY VUVUVUVU    =>  YUV420SP
 
 对于AV_PIX_FMT_YUV420P => YUV420P
 pointers[0] => {YYYY YYYY YYYY YYYY}
 pointers[1] => {UU UU}
 pointers[2] => {VV VV}
 
 linesizes[0] => 4
 linesizes[1] => 2
 linesizes[2] => 2
 */
typedef struct AV_Picture{
    uint8_t *pointers[AV_NUM_DATA_POINTERS];
    int linesize[AV_NUM_DATA_POINTERS];
}AV_Picture;

typedef struct AV_SwrBuffer{
    void *swrBuffer;    //释放
    int bufferSize;
}AV_SwrBuffer;

#pragma mark - Decoder

@interface Decoder (){
    AVFormatContext *_formatContext;
    AVCodecContext *_videoCodecContext;
    AVCodecContext *_audioCodecContext;
    AV_SwrBuffer *_swrBuffer;
    SwsContext *_swsContext;
    SwrContext *_swrContext;
    AV_Picture *_avPicture;
    AVFrame *_videoFrame;
    AVFrame *_audioFrame;
    pthread_mutex_t _pmutex;
    pthread_cond_t _pcond;
    pthread_t _pthread;
}
@property (weak, nonatomic) id<DecoderDelegate> delegate;

@property (strong, nonatomic) NSString *filePath;
@property (nonatomic) NSUInteger detectStartTime;
@property (nonatomic) unsigned int probesize;
@property (nonatomic) double videotimeBase;
@property (nonatomic) double audiotimeBase;
@property (nonatomic) int retryCount;
@property (nonatomic) BOOL exitThread;

@end

@implementation Decoder

- (void)dealloc
{
    NSLog(@"%s",__FUNCTION__);
}

- (instancetype)initWith:(NSString *)filePath delegate:(id<DecoderDelegate>)delegate
{
    self = [super init];
    if (self) {
        _delegate = delegate;
        _filePath = filePath;
        _probesize = 50 * 1024;
    }
    return self;
}

- (void)initBaseVariable{
    _status = DecoderUnOpen;
    _retryCount = 0;
    _endOfFile = NO;
    _exitThread = NO;
    _videotimeBase = 0;
    _audiotimeBase = 0;
}

- (void)openDecoder{
    [self initBaseVariable];
    [self initialDecoder];
    
    if (_audioCodecContext && _videoCodecContext) {
        pthread_mutex_init(&_pmutex, NULL);
        pthread_cond_init(&_pcond, NULL);
        
        /*
         pthread_t是遵循POSIX标准，定义了一套跨平台的多线程编程API
         */
        if (pthread_create(&_pthread, NULL, &ThreadMain, (__bridge void *)self)) {
            NSLog(@"There is some error Occurred when create decoder thread!");
            return;
        }
    }else{
        NSLog(@"Init AudioCodec and videoCodec fail!");
        ![self.delegate respondsToSelector:@selector(statusCallBack:)] ? : [self.delegate statusCallBack:_status];
    }
}

- (void)closeDecoder{
    /*
     1、判断当前状态为暂停状态时，再唤醒线程一次，使线程正确退出循环。
     */
    _exitThread = YES;
    pthread_mutex_lock(&_pmutex);
    if (_status == DecoderPause) {
        pthread_cond_signal(&_pcond);
    }
    pthread_mutex_unlock(&_pmutex);
    
    void *statue = NULL;
    pthread_join(_pthread, &statue);    //等待线程资源完全被释放
    if (statue && *(int *)statue) {
        NSLog(@"Occur an error when exit Pthread with %d",*(int *)statue);
        pthread_exit(&_pthread);    //强制终止线程
    }
    pthread_mutex_destroy(&_pmutex);
    pthread_cond_destroy(&_pcond);
    
    !_swrBuffer ? : free(_swrBuffer);
    _swrBuffer = NULL;
    !_swrContext ? : swr_free(&_swrContext);
    !_swsContext ? : sws_freeContext(_swsContext);
    _swsContext = NULL;
    !_audioFrame ? : av_frame_free(&_audioFrame);
    !_videoFrame ? : av_frame_free(&_videoFrame);
    !_audioCodecContext ? : avcodec_free_context(&_audioCodecContext);
    !_videoCodecContext ? : avcodec_free_context(&_videoCodecContext);
    avformat_close_input(&_formatContext);
    !_formatContext ? : avformat_free_context(_formatContext);
    _formatContext = NULL;
    
    NSLog(@"Close Decoder success!");
}

- (void)pauseDecoder{
    _status = DecoderPause;
    ![self.delegate respondsToSelector:@selector(statusCallBack:)] ? : [self.delegate statusCallBack:_status];
}

- (void)resumeDecoder{
    if (_endOfFile) {
        return;
    }
    
    switch (_status) {
        case DecoderUnOpen:
        case DecoderClosed:{
            [self openDecoder];
        }
        case DecoderOpened:
        case DecoderPause:{
            pthread_mutex_lock(&_pmutex);
            _status = DecoderDecoding;
            ![self.delegate respondsToSelector:@selector(statusCallBack:)] ? : [self.delegate statusCallBack:_status];
            pthread_cond_signal(&_pcond);
            pthread_mutex_unlock(&_pmutex);
        }
            break;
        default:
            break;
    }
}

- (void *)threadMain{
    _status = DecoderOpened;
    ![self.delegate respondsToSelector:@selector(statusCallBack:)] ? : [self.delegate statusCallBack:_status];
    
    /*
     预先解码1s的数据，以便获取视频的第一帧
     */
    _status = DecoderDecoding;
    [self decodePacket];
    _status = DecoderPause;
        
    while (!_exitThread) {
        pthread_mutex_lock(&_pmutex);
        pthread_cond_wait(&_pcond, &_pmutex);
        _exitThread ? : [self decodePacket];
        pthread_mutex_unlock(&_pmutex);
    }
    
    _status = DecoderClosed;
    //文件读取完毕不做状态回调
    if (!_endOfFile && [self.delegate respondsToSelector:@selector(statusCallBack:)]) {
        [self.delegate statusCallBack:_status];
    }
    
    NSLog(@"-----------------------Close Decoder!");
    
    return NULL;
}

- (void)initialDecoder{
    _detectStartTime = NSDate.new.timeIntervalSince1970;
    
    [self initialAVformat];
    
    if (_formatContext) {
        [self initialStreamInfo];
    }
}

- (void)initialAVformat{
    /*
     处理rtmp网络资源，其他网络可以继续追加
     */
    AVDictionary *option = NULL;
    const char *filePath = NULL;
    if ([_filePath hasPrefix:@"rtmp://"]) {
        filePath = [_filePath cStringUsingEncoding:NSUTF8StringEncoding];
        av_dict_set(&option, "rtmp_tcurl", filePath, 0);
    }else{
        filePath = [_filePath cStringUsingEncoding:NSUTF8StringEncoding];
    }
    
    if (!filePath || !strlen(filePath)) {
        NSLog(@"could not find the file with %@",_filePath);
        ![self.delegate respondsToSelector:@selector(statusCallBack:)] ? : [self.delegate statusCallBack:_status];
        return;
    }
    
    AVInputFormat *inputFormat = av_find_input_format([_filePath.pathExtension cStringUsingEncoding:NSUTF8StringEncoding]);
    
    /*
     初始化格式上下文
     */
    AVFormatContext *formatContext = avformat_alloc_context();
    /*
     中断回调，主要用于断点调试
     */
    formatContext->interrupt_callback = (AVIOInterruptCB){
        &InterruptCallback,
        (__bridge void *)self
    };
    int status = avformat_open_input(&formatContext, filePath, inputFormat, &option);
    if (status) {
        NSLog(@"could not open file with %s. Error code is %s",filePath,av_err2str(status));
        avformat_close_input(&formatContext);
        avformat_free_context(formatContext);
        ![self.delegate respondsToSelector:@selector(statusCallBack:)] ? : [self.delegate statusCallBack:_status];
        return;
    }
    
    /*
     获取资源的流信息(各个Stream 的MetaData，比如声音轨的声道数、采样率、表示格式或者视频轨的宽、高、fps等)
     1、探测数据量大小
     2、用于探测的帧数
     3、最大解析时间长度
     */
    formatContext->probesize = _probesize;
    formatContext->fps_probe_size = -1;
    formatContext->max_analyze_duration = 25000 * (3 + _retryCount);
    
    NSTimeInterval startTime = NSDate.timeIntervalSinceReferenceDate * 1000;
    status = avformat_find_stream_info(formatContext, &option);
    if (status) {
        /*
         寻找流信息失败直接退出
         */
        NSLog(@"could not find stream information. Error code is %s",av_err2str(status));
        avformat_close_input(&formatContext);
        avformat_free_context(formatContext);
        ![self.delegate respondsToSelector:@selector(statusCallBack:)] ? : [self.delegate statusCallBack:_status];
        return;
    }
    
    unsigned int nbStreams = formatContext->nb_streams;
    while (nbStreams--) {
        /*
         当流信息中有某个流信息编码格式未找到时，需断开再重新查找。
         */
        if (formatContext->streams[nbStreams]->codecpar->codec_id == AV_CODEC_ID_NONE) {
            NSLog(@"There is something streams information could not be found!");
            avformat_close_input(&formatContext);
            avformat_free_context(formatContext);
            
            //重试3次
            if (_retryCount++ < RetryCount) {
                [self initialAVformat];
                return;
            }
            //重试之后还不行直接失败返回
            ![self.delegate respondsToSelector:@selector(statusCallBack:)] ? : [self.delegate statusCallBack:_status];
            return;
        }
    }
    NSTimeInterval endTime = NSDate.timeIntervalSinceReferenceDate * 1000;
    NSLog(@"Waste %f to find stream information.",endTime - startTime);
    
    _formatContext = formatContext;
}

- (void)initialStreamInfo{
    /*
     查找对应流中的的编码信息
     */
    unsigned int nbStreams = _formatContext->nb_streams;
    while (nbStreams--) {
        AVCodecParameters *codecParameters = _formatContext->streams[nbStreams]->codecpar;
        
        AVStream *stream = _formatContext->streams[nbStreams];
        enum AVMediaType codecType = stream->codecpar->codec_type;
        switch (codecType) {
            case AVMEDIA_TYPE_VIDEO:
                [self openVideoStream:codecParameters];
                _videotimeBase = [self avStreamTimeBase:stream];
                break;
            case AVMEDIA_TYPE_AUDIO:
                [self openAudioStream:codecParameters];
                _audiotimeBase = [self avStreamTimeBase:stream];
                break;
            default:
                break;
        }
    }
}

- (void)openVideoStream:(AVCodecParameters *)codecParameters{
    AVCodec *avCodec = avcodec_find_decoder(codecParameters->codec_id);
    if (!avCodec) {
        NSLog(@"could not get file vidoe decoder %u.",avCodec->id);
        ![self.delegate respondsToSelector:@selector(statusCallBack:)] ? : [self.delegate statusCallBack:_status];
        return;
    }
    
    /*
     打开对应的解码器
     */
    AVCodecContext *codecContext = avcodec_alloc_context3(avCodec);
    //填充编码上下文
    int status = avcodec_parameters_to_context(codecContext, codecParameters);
    if (status < 0) {
        NSLog(@"could not fill the codec context. Error code is %s",av_err2str(status));
        ![self.delegate respondsToSelector:@selector(statusCallBack:)] ? : [self.delegate statusCallBack:_status];
        return;
    }
    
    status = avcodec_open2(codecContext, avCodec, NULL);
    if (status) {
        NSLog(@"could not open file vidoe decoder %u. Error code is %s",avCodec->id,av_err2str(status));
        avcodec_free_context(&codecContext);
        avcodec_close(codecContext);
        ![self.delegate respondsToSelector:@selector(statusCallBack:)] ? : [self.delegate statusCallBack:_status];
        return;
    }
    
    _videoFrame = av_frame_alloc();
    if (!_videoFrame) {
        NSLog(@"Occurs some error when Alloc video Frame");
        ![self.delegate respondsToSelector:@selector(statusCallBack:)] ? : [self.delegate statusCallBack:_status];
        return;
    }
    
    _videoCodecContext = codecContext;
}

- (void)openAudioStream:(AVCodecParameters *)codecParameters{
    AVCodec *avCodec = avcodec_find_decoder(codecParameters->codec_id);
    if (!avCodec) {
        NSLog(@"could not get file audio decoder %u.",avCodec->id);
        ![self.delegate respondsToSelector:@selector(statusCallBack:)] ? : [self.delegate statusCallBack:_status];
        return;
    }
    
    /*
     打开对应的解码器
     */
    AVCodecContext *codecContext = avcodec_alloc_context3(avCodec);
    //填充编码上下文
    int status = avcodec_parameters_to_context(codecContext, codecParameters);
    if (status < 0) {
        NSLog(@"could not fill the codec context. Error code is %s",av_err2str(status));
        ![self.delegate respondsToSelector:@selector(statusCallBack:)] ? : [self.delegate statusCallBack:_status];
        return;
    }
    
    status = avcodec_open2(codecContext, avCodec, NULL);
    if (status) {
        NSLog(@"could not open file audio decoder %u. Error code is %s",avCodec->id,av_err2str(status));
        avcodec_free_context(&codecContext);
        avcodec_close(codecContext);
        ![self.delegate respondsToSelector:@selector(statusCallBack:)] ? : [self.delegate statusCallBack:_status];
        return;
    }
    
    _audioFrame = av_frame_alloc();
    if (!_audioFrame) {
        NSLog(@"Occurs some error when Alloc audio Frame");
        ![self.delegate respondsToSelector:@selector(statusCallBack:)] ? : [self.delegate statusCallBack:_status];
        return;
    }
    
    _audioCodecContext = codecContext;
}

- (void)decodePacket{
    //更新侦查时间
    _detectStartTime = NSDate.new.timeIntervalSince1970;
    
    AVPacket *packet = av_packet_alloc();
    CGFloat duration = 0.f;
    /*
     以音频缓冲时间为准，超过最大缓冲时间则暂停解码
     */
    while (_status == DecoderDecoding && duration < Max_Buffered_Duration) {
        //读取编码数据出错或文件已读完情况
        if (av_read_frame(_formatContext, packet) < 0) {
            NSLog(@"Occurs an error when read frame.");
            av_packet_free(&packet);
            _endOfFile = YES;
            _exitThread = YES;
            break;
        }
        
        switch (packet->stream_index) {
            case AVMEDIA_TYPE_VIDEO:
                [self decodeVideoPacket:packet];
                break;
            case AVMEDIA_TYPE_AUDIO:
                duration += [self decodeAudioPacket:packet];
                break;
            default:
                break;
        }
    }
    !packet ? : av_packet_free(&packet);
    _status = DecoderPause;
    
    NSLog(@"-----------------------Pause Decoder!");
}

- (void)decodeVideoPacket:(AVPacket *)packet{
    int status = avcodec_send_packet(_videoCodecContext, packet);
    if (status != 0) {
        NSLog(@"Occurs an error when send packet to video decoder. Error code is %s",av_err2str(status));
        return;
    }
    
    BOOL runLoop = YES;
    while (runLoop) {
        status = avcodec_receive_frame(_videoCodecContext, _videoFrame);
        switch (status) {
            case 0:{
                Video_Frame *videoFrame = [self swsConvertToYUV:_videoFrame];
                videoFrame.position = _videoFrame->pts * _videotimeBase;
                videoFrame.duration = _videoFrame->pkt_duration * _videotimeBase;
                ![self.delegate respondsToSelector:@selector(decodedVideoPacket:)] ? : [self.delegate decodedVideoPacket:videoFrame];
            }
                break;
            case AVERROR_EOF:
            case AVERROR(EAGAIN):
                runLoop = NO;
                break;
            case AVERROR(EINVAL):
                NSLog(@"Codec not opened, or it is an encoder!");
                runLoop = NO;
                break;
            default:
                NSLog(@"Occurs an error when receive frame from video decoder. Error code is %s",av_err2str(status));
                runLoop = NO;
                break;
        }
    }
}

- (CGFloat)decodeAudioPacket:(AVPacket *)packet{
    CGFloat duration = 0.f;
    
    int status = avcodec_send_packet(_audioCodecContext, packet);
    if (status != 0) {
        NSLog(@"Occurs an error when send packet to audio decoder. Error code is %s",av_err2str(status));
        return duration;
    }
    
    BOOL runLoop = YES;
    while (runLoop) {
        status = avcodec_receive_frame(_audioCodecContext, _audioFrame);
        switch (status) {
            case 0:{
                Audio_Frame *audioFrame = [self swrConvertToS16:_audioFrame];
                audioFrame.position = _audioFrame->pts * _audiotimeBase;
                audioFrame.duration = _audioFrame->pkt_duration * _audiotimeBase;
                duration += audioFrame.duration;
                ![self.delegate respondsToSelector:@selector(decodedVideoPacket:)] ? : [self.delegate decodedAudioPacket:audioFrame];
            }
                break;
            case AVERROR_EOF:
            case AVERROR(EAGAIN):
                runLoop = NO;
                break;
            case AVERROR(EINVAL):
                NSLog(@"Codec not opened, or it is an encoder!");
                runLoop = NO;
                break;
            default:
                NSLog(@"Occurs an error when receive frame from audio decoder. Error code is %s",av_err2str(status));
                runLoop = NO;
                break;
        }
    }
    
    return duration;
}

- (Video_Frame *)swsConvertToYUV:(AVFrame *)videoFrame{
    /*
     Y分量没有数据直接返回
     */
    if (!videoFrame->data[0]) {
        return nil;
    }
    
    Video_Frame *frame = [[Video_Frame alloc] init];
    frame.height = videoFrame->height;
    frame.width = videoFrame->width;
    if (videoFrame->format == AV_PIX_FMT_YUV420P || videoFrame->format == AV_PIX_FMT_YUVJ420P) {
        /*
         分别复制YUV分量的Data
         */
        frame.data = [self copyYUVData:videoFrame->data[0] lineSize:videoFrame->linesize[0] width:videoFrame->width height:videoFrame->height];
        frame.crData = [self copyYUVData:videoFrame->data[1] lineSize:videoFrame->linesize[1] width:videoFrame->width / 2 height:videoFrame->height / 2];
        frame.cbData = [self copyYUVData:videoFrame->data[2] lineSize:videoFrame->linesize[2] width:videoFrame->width / 2 height:videoFrame->height / 2];
    }else{
        if (!_swsContext) {
            if (!_avPicture) {
                _avPicture = calloc(1, sizeof(AV_Picture));
            }
            
            /*
             根据宽、高、图片裸数据格式，新建一个图片结构体，用于存储接下来转换后的数据
             */
            int bufferSize = av_image_alloc(_avPicture->pointers, _avPicture->linesize, videoFrame->width, videoFrame->height, AV_PIX_FMT_YUV420P, 1);
            if (bufferSize < 0) {
                NSLog(@"Occurs an error when Allocating an image!");
                return nil;
            }
            
            /*
             复用或重新创建YUV420格式的图像转换上下文
             */
            _swsContext = sws_getCachedContext(_swsContext,
                                               videoFrame->width,
                                               videoFrame->height,
                                               videoFrame->format,
                                               videoFrame->width,
                                               videoFrame->height,
                                               AV_PIX_FMT_YUV420P,
                                               SWS_FAST_BILINEAR,
                                               NULL, NULL, NULL);
        }
        sws_scale(_swsContext, (const uint8_t *const *)videoFrame->data, videoFrame->linesize, 0, videoFrame->height, _avPicture->pointers, _avPicture->linesize);
        
        /*
         分别复制YUV分量的Data
         */
        frame.data = [self copyYUVData:_avPicture->pointers[0] lineSize:_avPicture->linesize[0] width:videoFrame->width height:videoFrame->height];
        frame.crData = [self copyYUVData:_avPicture->pointers[1] lineSize:_avPicture->linesize[1] width:videoFrame->width / 2 height:videoFrame->height / 2];
        frame.cbData = [self copyYUVData:_avPicture->pointers[2] lineSize:_avPicture->linesize[2] width:videoFrame->width / 2 height:videoFrame->height / 2];
    }
    return frame;
}

/*
 按行拷贝时，不能只以 lineSize 作为按行拷贝，还需参考当前帧的 width；
 因为视频帧可能是做过裁剪或其他操作
 */
- (NSData *)copyYUVData:(uint8_t *)data lineSize:(int)lineSize width:(int)width height:(int)height{
    int len = MIN(lineSize, width);
    NSMutableData *tempData = [NSMutableData dataWithLength:len * height];
    void *tempBytes = tempData.mutableBytes;
    
    for (int i = 0; i < height; i++) {
        memcpy(tempBytes, data, len);  //逐行拷贝
        data += lineSize;
        tempBytes += len;
    }
    return tempData;
}

- (Audio_Frame *)swrConvertToS16:(AVFrame *)audioFrame{
    /*
     解码之前先判断量化格式
     */
    int nbSamples = 0;
    void *buffer = NULL;
    AudioSampleFormat sampleFormat = AUDIO_SAMPLE_FMT_S16;
    if (audioFrame->format != AV_SAMPLE_FMT_S16) {
        if (!_swrContext) {
            /*
             根据参数创建 SwrContext，保持声道、采样率不变，只修改量化格式
             */
            SwrContext *swrContext = swr_alloc_set_opts(NULL,
                                                        av_get_default_channel_layout(audioFrame->channels),
                                                        AV_SAMPLE_FMT_S16,
                                                        audioFrame->sample_rate,
                                                        av_get_default_channel_layout(audioFrame->channels),
                                                        audioFrame->format,
                                                        audioFrame->sample_rate,
                                                        0, NULL);
            //初始化 SwrContext
            if (!swrContext || swr_init(swrContext)) {
                NSLog(@"Alloc or initialized SwrContext fail!");
                if (swrContext) {
                    swr_free(&swrContext);
                    swr_close(swrContext);
                }
                return nil;
            }
            _swrContext = swrContext;
        }
    
        if (!_swrBuffer) {
            _swrBuffer = calloc(1, sizeof(AV_SwrBuffer));
        }
        
        /*
         根据每一帧AudioFrame的声道数、采样率、最终转换的量化格式，重新创建存储这一帧的空间大小。
         由于量化格式可能是AV_SAMPLE_FMT_DBL -> AV_SAMPLE_FMT_S16是4倍，所以ratio = 4。
         所以最大的采样率可能是 nb_samples * ratio
         */
        int ratio = 4;
        int bufferSize = av_samples_get_buffer_size(NULL, audioFrame->channels, audioFrame->nb_samples * ratio, AV_SAMPLE_FMT_S16, 1);
        if (_swrBuffer->bufferSize < bufferSize) {
            _swrBuffer->swrBuffer = realloc(_swrBuffer->swrBuffer, bufferSize);
            _swrBuffer->bufferSize = bufferSize;
        }
        
        /*
         @param out       output buffers, only the first one need be set in case of packed audio
         @param in        input buffers, only the first one need to be set in case of packed audio
         所以 out、in 需要转换为指针数组或指针的指针
         */
        nbSamples = swr_convert(_swrContext, (uint8_t *[]){_swrBuffer->swrBuffer, NULL}, audioFrame->nb_samples * ratio, (const uint8_t**)audioFrame->data, audioFrame->nb_samples);
        if (nbSamples < 0) {
            NSLog(@"Swr convert FMT_S16 fail");
            return nil;
        }
        buffer = _swrBuffer->swrBuffer;
    }else{
        buffer = audioFrame->data[0];
        nbSamples = audioFrame->nb_samples;
    }

    NSUInteger datalength = 0;
    switch (sampleFormat) {
        case AUDIO_SAMPLE_FMT_S16:
            datalength = nbSamples * audioFrame->channels * sizeof(SInt16);
            break;
        default:
            break;
    }
    NSMutableData *data = [NSMutableData dataWithLength:datalength];
    memcpy(data.mutableBytes, buffer, data.length);
    
    Audio_Frame *frame = [[Audio_Frame alloc] init];
    frame.sampleFormat = sampleFormat;
    frame.frameType = AudioFrameType;
    frame.nbSamples = _audioCodecContext->sample_rate;
    frame.channels = _audioCodecContext->channels;
    frame.data = data.copy;
    return frame;
}

/*
 时间基准：
    1、Demux出来的帧对应于源AVStream的time_base。
    2、Mux出来的帧对应于目标AVStream的time_base。
    3、编码器出来的帧对应于目标AVCodecContext的time_base。
 */
- (double)avStreamTimeBase:(AVStream *)stream{
    double timeBase = av_q2d(AV_TIME_BASE_Q);
    
    if (stream->time_base.den && stream->time_base.num) {
        timeBase = av_q2d(stream->time_base);
    }else{
        switch (stream->codecpar->codec_type) {
            case AVMEDIA_TYPE_VIDEO:{
                if (_videoCodecContext->time_base.den && _videoCodecContext->time_base.num) {
                    timeBase = av_q2d(_videoCodecContext->time_base);
                }
            }
                break;
            case AVMEDIA_TYPE_AUDIO:
                if (_audioCodecContext->time_base.den && _audioCodecContext->time_base.num) {
                    timeBase = av_q2d(_audioCodecContext->time_base);
                }
                break;
            default:
                break;
        }
    }
    
    return timeBase;
}

- (int)occurInterrupt{
    int status = 0;
    if (NSDate.new.timeIntervalSince1970 - _detectStartTime > Detect_TimeOut) {
        NSLog(@"You are running Debug.It will be interrupt the play!");
        status = 1;
    }
    return status;
}

@end

static int InterruptCallback(void *context){
    int status = 0;
    if (context) {
        Decoder *decoder = (__bridge Decoder *)context;
        status = [decoder occurInterrupt];
    }
    return status;
}

static void * _Nullable ThreadMain(void * _Nullable arg){
    Decoder *decoder = (__bridge Decoder *)arg;
    return [decoder threadMain];
}
