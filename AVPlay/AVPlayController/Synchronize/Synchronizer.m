//
//  Synchronizer.m
//  AVPlay
//
//  Created by kakiYen on 2019/9/4.
//  Copyright © 2019 kakiYen. All rights reserved.
//

#import "NSObject+KVOObject.h"
#import "Synchronizer.h"
#import <pthread.h>

#define Min_Buffered_Duration .5f

static void * _Nullable ThreadMain(void * _Nullable arg);

@interface Synchronizer ()<DecoderDelegate>{
    pthread_mutex_t _pmutex;
    pthread_cond_t _pcond;
    pthread_t _pthread;
}
@property (weak, nonatomic) id<SynchronizerDelegate> delegate;

@property (strong, nonatomic) NSMutableArray<Video_Frame *> *videoFrames;
@property (strong, nonatomic) NSMutableArray<Audio_Frame *> *audioFrames;
@property (strong, nonatomic) Decoder *decoder;

@property (strong, nonatomic) dispatch_queue_t dispatchQueue;
@property (strong, nonatomic) dispatch_data_t dispatchData;
@property (nonatomic) NSTimeInterval audioInterval;
@property (nonatomic) CGFloat videoPosition;
@property (nonatomic) CGFloat videoDuration;
@property (nonatomic) CGFloat audioPosition;
@property (nonatomic) double bufferDuration;
@property (nonatomic) DecoderStatus status;
@property (nonatomic) BOOL isFirstAFrame;
@property (nonatomic) BOOL isFirstVFrame;
@property (nonatomic) BOOL exitThread;

@end

@implementation Synchronizer

- (void)dealloc
{
    NSLog(@"%s",__FUNCTION__);
}

- (instancetype)initWith:(NSString *)filePath delegate:(id<SynchronizerDelegate>)delegate
{
    self = [super init];
    if (self) {
        _delegate = delegate;
        _decoder = [[Decoder alloc] initWith:filePath delegate:self];
        _audioFrames = [NSMutableArray array];
        _videoFrames = [NSMutableArray array];
        _dispatchQueue = dispatch_queue_create("Synchronizer.Queue", DISPATCH_QUEUE_SERIAL);
        
        @weakify(self);
        [self addObserver:self forKeyPath:@"status" kvoCallBack:^(id _Nullable context, NSKeyValueChange valueChange, NSIndexSet * _Nullable indexes)
        {
            @strongify(self);
            [self notifyThread];
        }];
    }
    return self;
}

- (void)initBaseVariable{
    _status = DecoderUnOpen;
    _exitThread = NO;
    _isFirstVFrame = YES;
    _isFirstAFrame = YES;
    _audioInterval = 0;
    _audioPosition = 0;
    _videoPosition = 0;
    _videoDuration = 0;
    _bufferDuration = 0;
    _dispatchData = dispatch_data_empty;
    
    pthread_mutex_init(&_pmutex, NULL);
    pthread_cond_init(&_pcond, NULL);
    if(pthread_create(&_pthread, NULL, &ThreadMain, (__bridge void *)self)){
        NSLog(@"There is some error Occurred when create Synchronizer thread!");
    }
}

- (void)notifyThread{
    pthread_mutex_lock(&_pmutex);
    pthread_cond_signal(&_pcond);
    pthread_mutex_unlock(&_pmutex);
}

- (void *)threadMain{
    while (!_exitThread) {
        switch (_status) {
            case DecoderDecoding:
                [self correctVideoFrame];
                break;
            case DecoderUnOpen:
            default:
                pthread_mutex_lock(&_pmutex);
                NSLog(@"-----------------------Pause Synchronize Video!");
                pthread_cond_wait(&_pcond, &_pmutex);
                NSLog(@"-----------------------Start Synchronize Video!");
                pthread_mutex_unlock(&_pmutex);
                break;
        }
    }
    
    NSLog(@"-----------------------Close Synchronize Video!");
    
    return NULL;
}

//打开解码器
- (void)openSynchronizer{
    //已打开不需要再打开
    if (_status == DecoderOpened) {
        return;
    }
    
    dispatch_async(_dispatchQueue, ^{
        if (self.status == DecoderOpened) {
            return;
        }
        
        [self initBaseVariable];
        [self.decoder openDecoder];
    });
}

- (void)restartSynchronizer{
    [self closeSynchronizer];
    [self openSynchronizer];
}

- (void)pauseSynchronizer{
    [_decoder pauseDecoder];
}

- (void)closeSynchronizer{
    if (_exitThread) {
        return;
    }
    
    _exitThread = YES;
    [self.decoder closeDecoder];
    
    /*
     当原状态为正在编码时，线程是可以自动退出循环的；
     但为其他状态是需要再次通知线程退出。
     */
    pthread_mutex_lock(&_pmutex);
    if (_status != DecoderDecoding) {
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
    
    [_videoFrames removeAllObjects];
    [_audioFrames removeAllObjects];
    
    NSLog(@"Close Synchronizer success!");
}

- (void)statusCallBack:(DecoderStatus)status{
    self.status = status;
    ![self.delegate respondsToSelector:@selector(statusCallBack:)] ? : [self.delegate statusCallBack:_status];
}

- (void)decodedAudioPacket:(nonnull Audio_Frame *)audioFrame {
    if (_isFirstAFrame) {
        _isFirstAFrame = NO;
        ![self.delegate respondsToSelector:@selector(firstCorrectAudioFrame:)] ? : [self.delegate firstCorrectAudioFrame:audioFrame];
    }
    
    @synchronized (_audioFrames) {
        _bufferDuration += audioFrame.duration;
        [_audioFrames addObject:audioFrame];
    }
}

- (void)decodedVideoPacket:(nonnull Video_Frame *)videoFrame {
    /*
     获取到第一帧的视频帧时先回调一次
     */
    if (_isFirstVFrame) {
        _isFirstVFrame = NO;
        ![self.delegate respondsToSelector:@selector(firstCorrectVideoFrame:)] ? : [self.delegate firstCorrectVideoFrame:videoFrame];
    }
    
    @synchronized (_videoFrames) {
        [_videoFrames addObject:videoFrame];
    }
}

- (void)retrieveCallback:(SInt16 * _Nullable)ioData numberFrames:(UInt32)numberFrames numberChannels:(UInt32)numberChannels
{
    /*
     若文件已读取完毕则无需让解码器解码;
     所有音视频数据都播放完毕则关闭同步器。
     */
    if (_decoder.endOfFile) {
        if (self.endOfFile) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                ![self.delegate respondsToSelector:@selector(completePlayVideoFrame)] ? : [self.delegate completePlayVideoFrame];
            });
        }
        goto resumePlay;
    }
    
    /*
     若剩余缓冲时间小于最小缓冲时间则继续解码，或者没有视频帧，或者没有音频帧
     */
    if (_bufferDuration < Min_Buffered_Duration || !_videoFrames.count || !_audioFrames.count) {
        NSLog(@"_bufferDuration : %f, video count : %lu, audio count : %lu", _bufferDuration ,(unsigned long)_videoFrames.count,(unsigned long)_audioFrames.count);
        [_decoder resumeDecoder];
    }
    
resumePlay:
    {
        BOOL isContinue = YES;
        UInt32 needSize = numberFrames * numberChannels * sizeof(SInt16);
        
        while (numberFrames && isContinue) {
            size_t size = dispatch_data_get_size(_dispatchData);
            if (!size) {
                if (_audioFrames.count) {
                    _dispatchData = dispatch_data_create(_audioFrames.firstObject.data.bytes, _audioFrames.firstObject.data.length, NULL, DISPATCH_DATA_DESTRUCTOR_DEFAULT);
                    _audioPosition = _audioFrames.firstObject.position;
                    _audioInterval = NSDate.date.timeIntervalSince1970;
                    
                    @synchronized (_audioFrames) {
                        _bufferDuration -= _audioFrames.firstObject.duration;
                        [_audioFrames removeObjectAtIndex:0];
                    }
                }else{
                    _dispatchData = dispatch_data_empty;
                }
            }
            
            if (_dispatchData == dispatch_data_empty) {
                /*
                 无数据或不够数据填充情况
                 */
                memset(ioData, 0, needSize);
                isContinue = NO;
            }else{
                size = dispatch_data_get_size(_dispatchData);
                if (size) {
                    size_t copylen = MIN(needSize, size);
                    memcpy(ioData, ((NSData *)_dispatchData).bytes, copylen);
                    needSize -= copylen;
                    
                    _dispatchData = dispatch_data_create_subrange(_dispatchData, copylen, size - copylen);
                    /*
                     已完成填充
                     */
                    if (!needSize) {
                        isContinue = NO;
                    }
                }
            }
        }
    }
}

- (void)correctVideoFrame{
    BOOL exit = NO;
    while (_videoFrames.count > 0 && !exit) {
        NSTimeInterval now = NSDate.date.timeIntervalSince1970;
        /*
         某个视频帧的剩余播放时间 = 该视频帧的播放时刻 + 该视频帧的播放时长 - (当前音频的播放时刻 + 已播放的音频时长)
         ⚠️为防止 当前时间 < 当前音频的播放时刻 的Bug，故使用 MAX() 函数
         */
        CGFloat remainTime = _videoPosition + _videoDuration - (MAX(now - _audioInterval, 0) + _audioPosition);
        if (remainTime > 0.f) { //还有显示的剩余时间，依旧显示原来的视频帧
            break;
        }
        
        Video_Frame *nextFrame = _videoFrames.firstObject;
        _videoPosition = nextFrame.position;
        _videoDuration = nextFrame.duration;
        
        remainTime = _videoPosition + _videoDuration - (MAX(now - _audioInterval, 0) + _audioPosition);
        if (remainTime > 0.f) {
            ![self.delegate respondsToSelector:@selector(newCorrectVideoFrame:)] ? : [self.delegate newCorrectVideoFrame:nextFrame];
            exit = YES;
        }
        
        /*
         不合适的就剔除
         */
        @synchronized (_videoFrames) {
            [_videoFrames removeObjectAtIndex:0];
        }
    }
}

- (BOOL)endOfFile{
    BOOL eof = NO;
    if (_decoder.endOfFile) {
        if (!_audioFrames.count && !_videoFrames.count) {
            _status = DecoderClosed;
            eof = YES;
        }
    }
    return eof;
}

@end

static void * _Nullable ThreadMain(void * _Nullable arg){
    Synchronizer *synchronizer = (__bridge Synchronizer *)arg;
    return [synchronizer threadMain];
}
