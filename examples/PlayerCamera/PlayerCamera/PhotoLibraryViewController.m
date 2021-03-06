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
#import "UIViewController+Extensions.h"

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

@implementation PhotoLibrarySelectionItem
@end

@interface MediaCollectionViewCell : UICollectionViewCell

@property (nonatomic, weak) IBOutlet UIImageView* imageView;
@property (nonatomic, weak) IBOutlet UIImageView* badgeImage;
@property (nonatomic, weak) IBOutlet UILabel* durationLabel;
@property (nonatomic, weak) IBOutlet UILabel* indexLabel;

@end

@implementation MediaCollectionViewCell

@end

@interface PhotoLibraryViewController () <UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout>
{
    NSMutableArray<NSIndexPath* >* _selectedIndexPaths;
    NSMutableDictionary<NSIndexPath*, NSNumber* >* _indexPath2SelectionIndex;
}

@property (nonatomic, strong) NSMutableArray<PHAsset* >* dataSource;

@property (nonatomic, weak) IBOutlet UICollectionView* collectionView;

@property (nonatomic, weak) IBOutlet UINavigationBar* navBar;
@property (nonatomic, weak) IBOutlet UINavigationItem* navItem;
@property (nonatomic, strong) UIBarButtonItem* okButtonItem;

//@property (nonatomic, strong) UIActivityIndicatorView* loadingView;

@end

@implementation PhotoLibraryViewController

+(void) load {
    PHFetchOptions* fetchOptions = [[PHFetchOptions alloc] init];
    fetchOptions.includeHiddenAssets = NO;
    fetchOptions.includeAllBurstAssets = NO;
    fetchOptions.fetchLimit = 1;
    PHFetchResult* fetchResult = [PHAsset fetchAssetsWithOptions:fetchOptions];
    [fetchResult enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (NULL != stop)
            *stop = YES;
    }];
}

#pragma mark  UICollectionView Delegate&DataSource

-(void) collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    NSMutableArray<NSIndexPath* >* indexPathsToUpdate = [[NSMutableArray alloc] init];
    NSInteger selectionIndex = [_selectedIndexPaths indexOfObject:indexPath];
    if (NSNotFound == selectionIndex)
    {
        if (self.maxSelectionCount <= 0 || _selectedIndexPaths.count < self.maxSelectionCount)
        {
            [_selectedIndexPaths addObject:indexPath];
            [indexPathsToUpdate addObject:indexPath];
            [_indexPath2SelectionIndex setObject:@(_selectedIndexPaths.count) forKey:indexPath];
        }
        else if (self.maxSelectionCount == 1)
        {
            NSIndexPath* indexPath0= _selectedIndexPaths[0];
            [indexPathsToUpdate addObject:indexPath0];
            [indexPathsToUpdate addObject:indexPath];
            [_selectedIndexPaths removeAllObjects];
            [_selectedIndexPaths addObject:indexPath];
            [_indexPath2SelectionIndex removeAllObjects];
            [_indexPath2SelectionIndex setObject:@(_selectedIndexPaths.count) forKey:indexPath];
        }
        else
        {
            UIAlertController* alertCtrl = [UIAlertController alertControllerWithTitle:nil message:NSLocalizedString(@"ExceedSelectionLimit", @"Exceed selection limit") preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction* action = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"OK") style:UIAlertActionStyleDefault handler:nil];
            [alertCtrl addAction:action];
            [self showViewController:alertCtrl sender:self];
        }
    }
    else
    {
        for (NSUInteger i = selectionIndex; i < _selectedIndexPaths.count; ++i)
        {
            [indexPathsToUpdate addObject:_selectedIndexPaths[i]];
        }
        [_selectedIndexPaths removeObjectAtIndex:selectionIndex];
        
        [_indexPath2SelectionIndex removeAllObjects];
        for (NSUInteger i = 0; i < _selectedIndexPaths.count; ++i)
        {
            [_indexPath2SelectionIndex setObject:@(i + 1) forKey:_selectedIndexPaths[i]];
        }
    }
    [collectionView reloadItemsAtIndexPaths:indexPathsToUpdate];
    
    self.okButtonItem.enabled = (_selectedIndexPaths.count > 0);
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
    
    NSNumber* selectionIndex = _indexPath2SelectionIndex[indexPath];
    if (!selectionIndex)
    {
        cell.indexLabel.hidden = YES;
        if (self.maxSelectionCount > 1)
        {
            cell.badgeImage.hidden = NO;
            cell.badgeImage.image = [UIImage imageNamed:@"cell_to_select"];
        }
        else
        {
            cell.badgeImage.hidden = YES;
        }
    }
    else
    {
        if (self.maxSelectionCount > 1)
        {
            cell.indexLabel.hidden = NO;
            cell.indexLabel.text = [selectionIndex stringValue];
        }
        else
        {
            cell.indexLabel.hidden = YES;
        }
        cell.badgeImage.hidden = NO;
        cell.badgeImage.image = [UIImage imageNamed:@"cell_selected"];
    }
    return cell;
}

-(CGSize) collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat size = (self.collectionView.bounds.size.width - 6) / 3;
    return CGSizeMake(size, size);
}

-(void) dismissSelf {
    [self dismissActivityIndicatorView];
    [self dismissViewControllerAnimated:YES completion:nil];
}

-(void) confirm {
    self.collectionView.userInteractionEnabled = NO;
    [self showActivityIndicatorViewInView:nil];
    
    NSMutableArray<PhotoLibrarySelectionItem* >* results = [[NSMutableArray alloc] init];
    void(^completion)() = ^() {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.collectionView.userInteractionEnabled = YES;
            [self dismissSelf];
            if (self.selectCompletion)
            {
                self.selectCompletion([NSArray arrayWithArray:results]);
            }
        });
    };
    __block int jobsDone = 0;
    for (NSIndexPath* indexPath in _selectedIndexPaths)
    {
        PHAsset* phAsset = [self.dataSource objectAtIndex:indexPath.row];
        if (self.returnRawPHAssets)
        {
            PhotoLibrarySelectionItem* item = [[PhotoLibrarySelectionItem alloc] init];
            item.mediaType = phAsset.mediaType;
            item.resultOject = phAsset;
            [results addObject:item];
        }
        else
        {
            if (phAsset.mediaType == PHAssetMediaTypeImage)
            {
                PHImageRequestOptions* requestOptions = [[PHImageRequestOptions alloc] init];
                requestOptions.networkAccessAllowed = YES;
                requestOptions.progressHandler = ^(double progress, NSError * _Nullable error, BOOL * _Nonnull stop, NSDictionary * _Nullable info) {
                    [self showActivityIndicatorViewInView:nil withText:[NSString stringWithFormat:@"%d/%d", (jobsDone+1), (int)_selectedIndexPaths.count]];
                };
                [[PHCachingImageManager defaultManager] requestImageDataForAsset:phAsset options:requestOptions resultHandler:^(NSData * _Nullable imageData, NSString * _Nullable dataUTI, UIImageOrientation orientation, NSDictionary * _Nullable info) {
                    PhotoLibrarySelectionItem* item = [[PhotoLibrarySelectionItem alloc] init];
                    item.mediaType = PHAssetMediaTypeImage;
                    item.resultOject = imageData;
                    [results addObject:item];
                    if (++jobsDone == _selectedIndexPaths.count)
                    {
                        completion();
                    }
                }];
            }
            else if (phAsset.mediaType == PHAssetMediaTypeVideo)
            {
                PHVideoRequestOptions* requestOptions = [[PHVideoRequestOptions alloc] init];
                requestOptions.networkAccessAllowed = YES;
                requestOptions.progressHandler = ^(double progress, NSError * _Nullable error, BOOL * _Nonnull stop, NSDictionary * _Nullable info) {
                    [self showActivityIndicatorViewInView:nil withText:[NSString stringWithFormat:@"%@ %0.0f%%", NSLocalizedString(@"FetchingVideo", @"FetchingVideo"), progress * 100.f]];
                };
                [[PHImageManager defaultManager] requestAVAssetForVideo:phAsset options:requestOptions resultHandler:^(AVAsset * _Nullable asset, AVAudioMix * _Nullable audioMix, NSDictionary * _Nullable info) {
                    AVURLAsset* urlAsset = (AVURLAsset*)asset;
                    if (!urlAsset)
                    {
                        if (++jobsDone == _selectedIndexPaths.count)
                        {
                            completion();
                        }
                        return;
                    }
//                    NSString* sandboxExtensionTokenKey = info[@"PHImageFileSandboxExtensionTokenKey"];
//                    NSArray* components = [sandboxExtensionTokenKey componentsSeparatedByString:@";"];
//                    NSString* videoPath = [components.lastObject substringFromIndex:9];
//                    PhotoLibrarySelectionItem* item = [[PhotoLibrarySelectionItem alloc] init];
//                    item.mediaType = PHAssetMediaTypeVideo;
//                    item.resultOject = urlAsset.URL.absoluteString;
//                    [results addObject:item];
//                    if (results.count == _selectedIndexPaths.count)
//                    {
//                        completion();
//                    }
                    NSString* tmpFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:urlAsset.URL.absoluteString.lastPathComponent];
                    AVAssetExportSession* exporter = [[AVAssetExportSession alloc] initWithAsset:urlAsset presetName:AVAssetExportPresetHighestQuality];
                    exporter.outputURL = [NSURL fileURLWithPath:tmpFilePath];
                    exporter.outputFileType = AVFileTypeQuickTimeMovie;
                    exporter.shouldOptimizeForNetworkUse = YES;
                    NSTimer* progressTimer = [NSTimer timerWithTimeInterval:0.2f repeats:YES block:^(NSTimer * _Nonnull timer) {
                        [self showActivityIndicatorViewInView:nil withText:[NSString stringWithFormat:@"%@ %0.0f%%", NSLocalizedString(@"ConvertingVideo", @"ConvertingVideo"), exporter.progress * 100.f]];
                    }];
                    [exporter exportAsynchronouslyWithCompletionHandler:^{
                        dispatch_async(dispatch_get_main_queue(), ^{
                            if (exporter.status == AVAssetExportSessionStatusCompleted)
                            {
                                PhotoLibrarySelectionItem* item = [[PhotoLibrarySelectionItem alloc] init];
                                item.mediaType = PHAssetMediaTypeVideo;
                                item.resultOject = exporter.outputURL.absoluteString;
                                [results addObject:item];
                            }
                            else
                            {
                                UIAlertController* alertCtrl = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"ConvertingFailure", @"ConvertingFailure") message:exporter.error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
                                UIAlertAction* action = [UIAlertAction actionWithTitle:NSLocalizedString(@"GotIt", @"GotIt") style:UIAlertActionStyleDefault handler:nil];
                                [alertCtrl addAction:action];
                                [self showViewController:alertCtrl sender:self];
                            }
                            if (++jobsDone == _selectedIndexPaths.count)
                            {
                                [progressTimer invalidate];
                                completion();
                            }
                        });
                    }];
                    [[NSRunLoop mainRunLoop] addTimer:progressTimer forMode:NSDefaultRunLoopMode];
                }];
            }
        }
    }
    if (self.returnRawPHAssets)
    {
        completion();
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    UIBarButtonItem* dismissButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"btn_back"]
                                                                          style:UIBarButtonItemStylePlain
                                                                         target:self
                                                                         action:@selector(dismissSelf)];
    self.navItem.leftBarButtonItem = dismissButtonItem;
    
    self.okButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"confirm"]
                                                                     style:UIBarButtonItemStylePlain
                                                                    target:self
                                                                    action:@selector(confirm)];
    self.okButtonItem.enabled = NO;
    self.navItem.rightBarButtonItem = self.okButtonItem;
    
    self.navItem.title = NSLocalizedString(@"SelectMedias", @"Select Photo/Video");
    
    [self.navBar makeTranslucent];
    [self setNeedsStatusBarAppearanceUpdate];

//    self.loadingView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
//    self.loadingView.center = self.view.center;
//    [self.view addSubview:self.loadingView];
//    self.loadingView.translatesAutoresizingMaskIntoConstraints = YES;
    
    _selectedIndexPaths = [[NSMutableArray alloc] init];
    _indexPath2SelectionIndex = [[NSMutableDictionary alloc] init];
    
    self.dataSource = [[NSMutableArray alloc] init];
    PHFetchOptions* fetchOptions = [[PHFetchOptions alloc] init];
    fetchOptions.includeHiddenAssets = NO;
    fetchOptions.includeAllBurstAssets = YES;
    PHFetchResult* fetchResult = [PHAsset fetchAssetsWithOptions:fetchOptions];
    [fetchResult enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        PHAsset* phAsset = (PHAsset*)obj;
        if (!self.allowedMediaTypes || [self.allowedMediaTypes containsObject:@(phAsset.mediaType)])
        {
            [self.dataSource addObject:phAsset];
        }
    }];
    [self.collectionView reloadData];
}

-(void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
    if (status == PHAuthorizationStatusDenied)
    {
        UIAlertController* alertCtrl = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"PermissionDenied", @"PermissionDenied") message:NSLocalizedString(@"NeedPhotoLibraryPermission", @"NeedPhotoLibraryPermission") preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction* actionOK = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"OK") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            NSURL* url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
            if ([[UIApplication sharedApplication] canOpenURL:url])
            {
                if (@available(iOS 10.0, *))
                {
                    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:^(BOOL success) {
                    }];
                }
                else
                {
                    [[UIApplication sharedApplication] openURL:url];
                }
            }
            /*
             作者：MajorLMJ
             链接：https://www.jianshu.com/p/b44f309feca0
             來源：简书
             简书著作权归作者所有，任何形式的转载都请联系作者获得授权并注明出处。
             //*/
        }];
        [alertCtrl addAction:actionOK];
        UIAlertAction* actionCancel = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"Cancel") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        }];
        [alertCtrl addAction:actionCancel];
        [self presentViewController:alertCtrl animated:NO completion:^{
            
        }];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
