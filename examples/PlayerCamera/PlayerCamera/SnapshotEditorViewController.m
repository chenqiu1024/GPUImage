//
//  SnapshotEditorViewController.m
//  GijkPlayer
//
//  Created by DOM QIU on 2018/7/2.
//  Copyright © 2018 DOM QIU. All rights reserved.
//

#import "SnapshotEditorViewController.h"
#import <GPUImage.h>

@interface SnapshotEditorViewController ()

@end

@implementation SnapshotEditorViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    if (!self.image)
        return;
    
    GPUImageView* gpuImageView = (GPUImageView*)self.view;
    GPUImagePicture* picture = [[GPUImagePicture alloc] initWithImage:self.image];
    [picture addTarget:gpuImageView];
    [picture processImage];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
