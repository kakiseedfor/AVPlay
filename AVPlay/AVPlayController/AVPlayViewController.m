//
//  PngPreviewVC.m
//  Audio and Video Play
//
//  Created by kakiYen on 2019/8/20.
//  Copyright © 2019 kakiYen. All rights reserved.
//

#import "AVPlayViewController.h"
#import "AVPlayController.h"

@interface AVPlayViewController ()<AVPlayControllerProtocol>
@property (weak, nonatomic) IBOutlet UIView *playView;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *optionBtn;
@property (strong, nonatomic) AVPlayController *playController;
@property (strong, nonatomic) NSString *filePath;
@property (nonatomic) BOOL isClose;
@property (nonatomic) BOOL isPause;
@property (nonatomic) BOOL isZoom;

@end

@implementation AVPlayViewController

- (void)dealloc
{
    NSLog(@"%s",__FUNCTION__);
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    UITapGestureRecognizer *doubleTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(doubleTapAction:)];
    doubleTapGesture.numberOfTapsRequired = 2;
    [self.view addGestureRecognizer:doubleTapGesture];
    
    UITapGestureRecognizer *singleTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(singleTapAction:)];
    singleTapGesture.numberOfTapsRequired = 1;
    [self.view addGestureRecognizer:singleTapGesture];
    [singleTapGesture requireGestureRecognizerToFail:doubleTapGesture];
    
    _isPause = YES;
    _playController = [[AVPlayController alloc] init:_filePath parentView:self.view delegate:self];
    [_playController setAutoStart:!_isPause];
    [_playController openAVPlay];
}

+ (void)showAVPlayVC:(NSString *)filePath{
    UIStoryboard *storybaord = [UIStoryboard storyboardWithName:@"Main" bundle:NSBundle.mainBundle];
    AVPlayViewController *tempVC = [storybaord instantiateViewControllerWithIdentifier:@"AVPlayViewController"];
    [tempVC setFilePath:filePath];
    [TopViewController.navigationController pushViewController:tempVC animated:YES];
}

- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    [_playController resumeAVPlay];
}

- (void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    [_playController pauseAVPlay];
}

- (void)didReceiveMemoryWarning{
    [super didReceiveMemoryWarning];
    [_playController closeAVPlay];
}

- (IBAction)optionAction:(id)sender {
    _isClose = !_isClose;
    _isClose ? [_playController closeAVPlay] : [_playController restartAVPlay];
    _optionBtn.title = _isClose ? @"打开" : @"关闭";
}

- (void)singleTapAction:(UITapGestureRecognizer *)tap{
    _isPause = !_isPause;
    _isPause ? [_playController pauseAVPlay] : [_playController resumeAVPlay];
}

- (void)doubleTapAction:(UITapGestureRecognizer *)tap{
    _isZoom = !_isZoom;
    [_playController setParentView:_isZoom ? self.playView : self.view];
}

- (void)setFilePath:(NSString *)filePath{
    _filePath = filePath;
}

- (void)statusCallBack:(AVPlayStatus)status{
    
}

@end
