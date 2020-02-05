//
//  ViewController.m
//  Audio and Video Play
//
//  Created by kakiYen on 2019/8/20.
//  Copyright © 2019 kakiYen. All rights reserved.
//

#import "AVRecordViewController.h"
#import "AVPlayViewController.h"
#import "ViewController.h"
#import "NSDate+String.h"
#import <objc/runtime.h>

@interface ViewController ()<UITableViewDelegate, UITableViewDataSource>
@property (weak, nonatomic) IBOutlet UIBarButtonItem *recordBtn;
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (strong, nonatomic) NSMutableArray<NSString *> *dataArray;

@end

@implementation ViewController

- (void)updateList{
    @weakify(self);
    [self addObserver:self forKeyPath:@"dataArray" kvoCallBack:^(id _Nullable context, NSKeyValueChange valueChange, NSIndexSet * _Nullable indexes)
    {
        @strongify(self);
        NSMutableArray *tempArray = [NSMutableArray array];
        [indexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
            [tempArray addObject:[NSIndexPath indexPathForRow:idx inSection:0]];
        }];
        
        switch (valueChange) {
            case NSKeyValueChangeSetting:
            case NSKeyValueChangeInsertion:
                [self.tableView insertRowsAtIndexPaths:tempArray withRowAnimation:UITableViewRowAnimationFade];
                break;
            case NSKeyValueChangeRemoval:{
                [self.tableView deleteRowsAtIndexPaths:tempArray withRowAnimation:UITableViewRowAnimationFade];
            }
                break;
            default:
                break;
        }
    }];
    [self.proxyArray removeAllObjects];
    [self.proxyArray addObjectsFromArray:BundleWithAllResource];
    
    NSError *error = nil;
    NSString *filePath = InCachesDirectory(@"Record");
    NSArray *temp = [NSFileManager.defaultManager contentsOfDirectoryAtPath:filePath error:&error];
    
    [temp enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *tempFilePath = [filePath stringByAppendingFormat:@"/%@",obj];
        BOOL isDirectory = NO;
        if ([NSFileManager.defaultManager fileExistsAtPath:tempFilePath isDirectory:&isDirectory]) {
            isDirectory ? : [self.proxyArray addObject:tempFilePath];
        }
    }];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [_tableView registerClass:UITableViewCell.class forCellReuseIdentifier:ClassName(UITableViewCell.class)];
}

- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    [self updateList];
}

- (IBAction)recordAction:(id)sender {
    [AVRecordViewController showAVPlayRVC];
}

#pragma mark - UITableViewDelegate, UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return _dataArray.count;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath{
    return YES;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:ClassName(UITableViewCell.class) forIndexPath:indexPath];
    cell.textLabel.text = _dataArray[indexPath.row].lastPathComponent;
    return cell;
}

- (NSArray<UITableViewRowAction *> *)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(NSIndexPath *)indexPath{
    UITableViewRowAction *deleteAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDefault title:@"删除" handler:^(UITableViewRowAction * _Nonnull action, NSIndexPath * _Nonnull indexPath)
    {
        NSError *error = nil;
        [NSFileManager.defaultManager removeItemAtPath:self.dataArray[indexPath.row] error:&error];
        !error ? : NSLog(@"%@",error.userInfo[@"NSUnderlyingError"]);
        
        error ? : [self.proxyArray removeObjectAtIndex:indexPath.row];
    }];
    return @[deleteAction];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    NSString *filePath = _dataArray[indexPath.row];
    if ([filePath hasSuffix:@".flv"]) {
        [AVPlayViewController showAVPlayVC:filePath];
    }
}

#pragma mark - NSMutableArray KVC

/*
 容器对象方法可选，但必须成对实现。
 */
-(void)insertObject:(id)object inDataArrayAtIndex:(NSUInteger)index{
    [self.dataArray insertObject:object atIndex:index];
}

-(void)removeObjectFromDataArrayAtIndex:(NSUInteger)index{
    [self.dataArray removeObjectAtIndex:index];
}

#pragma mark - Getter or Setter

- (NSMutableArray<NSString *> *)proxyArray{
    return [self mutableArrayValueForKeyPath:@"dataArray"];
}

- (NSMutableArray<NSString *> *)dataArray{
    if (!_dataArray) {
        _dataArray = [NSMutableArray array];
    }
    return _dataArray;
}



@end
