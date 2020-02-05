//
//  AVPlayRViewController.m
//  AVPlay
//
//  Created by kakiYen on 2019/11/21.
//  Copyright © 2019 kakiYen. All rights reserved.
//

#import "AVRecordViewController.h"
#import "AVRecordController.h"

@interface AVRecordViewController ()
@property (nonatomic) BOOL isBegin;
@property (nonatomic) BOOL isPause;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *optionBtn;
@property (strong, nonatomic) AVRecordController *recordController;

@end

@implementation AVRecordViewController

- (void)dealloc
{
    NSLog(@"%s",__FUNCTION__);
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapAction:)];
    tapGesture.numberOfTapsRequired = 1;
    [self.view addGestureRecognizer:tapGesture];
    
    _recordController = [[AVRecordController alloc] initWith:self.view];
    [_recordController startRecord];
}

- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    [_recordController startRecord];
}

- (void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    [_recordController stopRecord];
}

- (void)didReceiveMemoryWarning{
    [super didReceiveMemoryWarning];
}

+ (void)showAVPlayRVC{
    UIStoryboard *storybaord = [UIStoryboard storyboardWithName:@"Main" bundle:NSBundle.mainBundle];
    AVRecordViewController *tempVC = [storybaord instantiateViewControllerWithIdentifier:@"AVRecordViewController"];
    [TopViewController.navigationController pushViewController:tempVC animated:YES];
}

- (IBAction)optionAction:(id)sender {
    _isBegin = !_isBegin;
    _optionBtn.title = _isBegin ? @"停止" : @"开始";
    [_recordController setOpenRecord:_isBegin];
}

- (void)tapAction:(UITapGestureRecognizer *)tap{
    _isPause = !_isPause;
}

@end
