//
//  PhotoLibraryViewController.m
//  PlayerCamera
//
//  Created by DOM QIU on 2018/7/6.
//  Copyright © 2018 DOM QIU. All rights reserved.
//

#import "PhotoLibraryViewController.h"
#import "UINavigationBar+Translucent.h"
#import "CameraPlayerViewController.h"

static NSString* MediaCellIdentifier = @"MediaCell";

NSString* durationString(NSTimeInterval duration) {
    int seconds = (int)round(duration);
    int minutes = seconds / 60;
    seconds = seconds % 60;
    int hours = minutes / 60;
    minutes = minutes % 60;
    if (hours > 0)
        return [NSString stringWithFormat:@"%02d:%02d:%02d", hours, minutes, seconds];
    else
        return [NSString stringWithFormat:@"%02d:%02d", minutes, seconds];
}

@interface MediaCollectionViewCell : UICollectionViewCell

@property (nonatomic, weak) IBOutlet UIImageView* imageView;
@property (nonatomic, weak) IBOutlet UILabel* durationLabel;

@end

@implementation MediaCollectionViewCell

@end

@interface PhotoLibraryViewController () <UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout>

@property (nonatomic, strong) NSMutableArray<PHAsset* >* dataSource;

@property (nonatomic, weak) IBOutlet UICollectionView* collectionView;

@property (nonatomic, weak) IBOutlet UINavigationBar* navBar;
@property (nonatomic, weak) IBOutlet UINavigationItem* navItem;

@end

@implementation PhotoLibraryViewController

#pragma mark  UICollectionView Delegate&DataSource

-(void) collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    PHAsset* phAsset = [self.dataSource objectAtIndex:indexPath.row];
    if (phAsset.mediaType == PHAssetMediaTypeImage)
    {
        PHImageRequestOptions* requestOptions = [[PHImageRequestOptions alloc] init];
        requestOptions.networkAccessAllowed = YES;
        [[PHCachingImageManager defaultManager] requestImageDataForAsset:phAsset options:requestOptions resultHandler:^(NSData * _Nullable imageData, NSString * _Nullable dataUTI, UIImageOrientation orientation, NSDictionary * _Nullable info) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self dismissSelf];
                if (self.selectCompletion)
                {
                    self.selectCompletion(imageData, PHAssetMediaTypeImage);
                }
            });
        }];
    }
    else if (phAsset.mediaType == PHAssetMediaTypeVideo)
    {
        PHVideoRequestOptions* requestOptions = [[PHVideoRequestOptions alloc] init];
        requestOptions.networkAccessAllowed = YES;
        [[PHCachingImageManager defaultManager] requestAVAssetForVideo:phAsset options:requestOptions resultHandler:^(AVAsset * _Nullable asset, AVAudioMix * _Nullable audioMix, NSDictionary * _Nullable info) {
            NSString* sandboxExtensionTokenKey = info[@"PHImageFileSandboxExtensionTokenKey"];
            NSArray* components = [sandboxExtensionTokenKey componentsSeparatedByString:@";"];
            NSString* videoPath = [components.lastObject substringFromIndex:9];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self dismissSelf];
                if (self.selectCompletion)
                {
                    self.selectCompletion(videoPath, PHAssetMediaTypeVideo);
                }
            });
        }];
    }
}

-(NSInteger) numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

-(NSInteger) collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.dataSource.count;
}

-(__kindof UICollectionViewCell*) collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    MediaCollectionViewCell* cell = [collectionView dequeueReusableCellWithReuseIdentifier:MediaCellIdentifier forIndexPath:indexPath];
    
    CGSize cellSize = [self collectionView:collectionView layout:collectionView.collectionViewLayout sizeForItemAtIndexPath:indexPath];
    cellSize = CGSizeMake(cellSize.width * [UIScreen mainScreen].scale, cellSize.height * [UIScreen mainScreen].scale);
    PHAsset* phAsset = [self.dataSource objectAtIndex:indexPath.row];
    [[PHCachingImageManager defaultManager] requestImageForAsset:phAsset targetSize:cellSize contentMode:PHImageContentModeAspectFit options:nil resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info) {
        if (phAsset.mediaType != PHAssetMediaTypeImage)
        {
            cell.durationLabel.hidden = NO;
            cell.durationLabel.text = durationString(phAsset.duration);
        }
        else
        {
            cell.durationLabel.hidden = YES;
        }
        cell.imageView.image = result;
    }];
    return cell;
}

-(CGSize) collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat size = (self.collectionView.bounds.size.width - 6) / 3;
    return CGSizeMake(size, size);
}

-(void) dismissSelf {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    UIBarButtonItem* dismissButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"btn_back"]
                                                                          style:UIBarButtonItemStylePlain
                                                                         target:self
                                                                         action:@selector(dismissSelf)];
    self.navItem.leftBarButtonItem = dismissButtonItem;
    self.navItem.title = @"Select Photo/Video";
    
    [self.navBar makeTranslucent];
    [self setNeedsStatusBarAppearanceUpdate];
    
    self.dataSource = [[NSMutableArray alloc] init];
    PHFetchOptions* fetchOptions = [[PHFetchOptions alloc] init];
    fetchOptions.includeHiddenAssets = NO;
    fetchOptions.includeAllBurstAssets = YES;
    PHFetchResult* fetchResult = [PHAsset fetchAssetsWithOptions:fetchOptions];
    [fetchResult enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        PHAsset* phAsset = (PHAsset*)obj;
        [self.dataSource addObject:phAsset];
    }];
    [self.collectionView reloadData];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
