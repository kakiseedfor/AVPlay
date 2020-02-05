//
//  RecordController.h
//  AVPlay
//
//  Created by kakiYen on 2019/11/11.
//  Copyright © 2019 kakiYen. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, AVRecordStatus) {
    AVRecordUnOpen,
    AVRecordOpened,
    AVRecordPause,
    AVRecordClosed,
};

@protocol AVRecordControllerProtocol <NSObject>

- (void)statusCallBack:(AVRecordStatus)status;

@end

NS_ASSUME_NONNULL_BEGIN

@interface AVRecordController : NSObject

- (instancetype)initWith:(UIView *)parentView;  //主线程

- (void)setParentView:(UIView *)parentView;

- (void)setOpenRecord:(BOOL)openRecord; //是否开始录制

- (void)closeRecord;

- (void)startRecord;

- (void)stopRecord;

@end

NS_ASSUME_NONNULL_END
