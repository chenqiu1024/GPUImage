//
//  StartingGridViewController.m
//  PlayerCamera
//
//  Created by DOM QIU on 2018/7/7.
//  Copyright © 2018 DOM QIU. All rights reserved.
//

#import "StartingGridViewController.h"
#import "UINavigationBar+Translucent.h"
#import "PhotoLibraryViewController.h"
#import "UIViewController+Extensions.h"
#import "SnapshotEditorViewController.h"
#import "CameraDictateViewController.h"
#import "VideoSnapshotViewController.h"
#import "CameraPlayerViewController.h"
#import "UIImage+Share.h"
#import "WXApiRequestHandler.h"
#import "WeiXinConstant.h""
#import "PhotoLibraryHelper.h"
#import <Photos/Photos.h>

const int MaxCells = 9;
static NSString* StartingGridCellIdentifier = @"StartingGrid";

@interface BlankImagePlaceHolder : NSObject
@end

@implementation BlankImagePlaceHolder
@end

@interface StartingGridCell : UICollectionViewCell

@property (nonatomic, weak) IBOutlet UIImageView* imageView;
@property (nonatomic, weak) IBOutlet UILabel* numberLabel;
@property (nonatomic, weak) IBOutlet UIActivityIndicatorView* loadingView;
@property (nonatomic, weak) IBOutlet UIButton* deleteButton;

@property (nonatomic, copy) void(^deleteButtonHandler)();

@end

@implementation StartingGridCell

-(void) onDeleteButtonPressed:(id)sender {
    if (self.deleteButtonHandler)
    {
        self.deleteButtonHandler();
    }
}

-(void) awakeFromNib {
    [super awakeFromNib];
    [self.deleteButton addTarget:self action:@selector(onDeleteButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
}

@end

@interface StartingGridViewController () <UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, UICollectionViewDataSource>

@property (nonatomic, weak) IBOutlet UICollectionView* collectionView;

@property (nonatomic, weak) IBOutlet UINavigationBar* navBar;
@property (nonatomic, weak) IBOutlet UINavigationItem* navItem;
@property (nonatomic, strong) UIBarButtonItem* okButtonItem;

@property (nonatomic, strong) NSMutableArray<NSObject* >* imageAssets;
@property (nonatomic, strong) NSMutableDictionary<NSIndexPath*, UIImage* >* thumbnails;
//@property (nonatomic, strong) NSMutableSet<NSIndexPath* >* loadingCells;

@end

@implementation StartingGridViewController

-(void) checkIfAnyImage {
    for (NSObject* obj in self.imageAssets)
    {
        if (![obj isKindOfClass:BlankImagePlaceHolder.class])
        {
            self.navItem.rightBarButtonItem.enabled = YES;
            return;
        }
    }
    self.navItem.rightBarButtonItem.enabled = NO;
}

-(NSInteger) numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

-(NSInteger) collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.imageAssets.count == MaxCells ? MaxCells : self.imageAssets.count + 1;
}

-(void) deleteItemAt:(NSIndexPath*)indexPath {
    BlankImagePlaceHolder* placeHolder = [[BlankImagePlaceHolder alloc] init];
    [self.imageAssets replaceObjectAtIndex:indexPath.row withObject:placeHolder];
    [self checkIfAnyImage];
    [self.thumbnails removeObjectForKey:indexPath];
    [self.collectionView reloadItemsAtIndexPaths:@[indexPath]];
}

-(__kindof UICollectionViewCell*) collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    StartingGridCell* cell = [collectionView dequeueReusableCellWithReuseIdentifier:StartingGridCellIdentifier forIndexPath:indexPath];
    [cell.loadingView stopAnimating];
    cell.loadingView.hidden = YES;
    if (indexPath.row >= self.imageAssets.count)
    {
        cell.numberLabel.hidden = NO;
        cell.numberLabel.text = @"+";///[@(indexPath.row + 1) stringValue];
        cell.imageView.image = nil;//[UIImage imageNamed:@"addphoto_43x43_"];
        cell.deleteButton.hidden = YES;
        cell.deleteButtonHandler = nil;
    }
    else
    {
        NSObject* item = self.imageAssets[indexPath.row];
        if ([item isKindOfClass:BlankImagePlaceHolder.class])
        {
            cell.numberLabel.hidden = NO;
            cell.numberLabel.text = @"+";///[@(indexPath.row + 1) stringValue];
            cell.imageView.image = nil;//[UIImage imageNamed:@"addphoto_43x43_"];
            cell.deleteButton.hidden = YES;
            cell.deleteButtonHandler = nil;
        }
        else
        {
            cell.numberLabel.hidden = YES;
            UIImage* thumbnail = [self.thumbnails objectForKey:indexPath];
            cell.imageView.image = thumbnail;
            if (!thumbnail)
            {
                cell.loadingView.hidden = NO;
                [cell.loadingView startAnimating];
            }
            cell.deleteButton.hidden = NO;
            cell.deleteButtonHandler = ^{
                [self deleteItemAt:indexPath];
            };
        }
    }
    
    return cell;
}

-(CGSize) collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat size = (self.collectionView.bounds.size.width - 6) / 3;
    return CGSizeMake(size, size);
}

-(void) replaceOrAddPHAsset:(PHAsset*)phAsset atIndexPath:(NSIndexPath*)indexPath {
    if (!phAsset)
        return;
    
    CGSize cellSize = [self collectionView:self.collectionView layout:self.collectionView.collectionViewLayout sizeForItemAtIndexPath:indexPath];
    cellSize = CGSizeMake(cellSize.width * [UIScreen mainScreen].scale, cellSize.height * [UIScreen mainScreen].scale);
    
    if (indexPath.row >= self.imageAssets.count)
        [self.imageAssets addObject:phAsset];
    else
        [self.imageAssets replaceObjectAtIndex:indexPath.row withObject:phAsset];
    self.navItem.rightBarButtonItem.enabled = YES;
    [self.thumbnails removeObjectForKey:indexPath];
    [self.collectionView reloadData];
    
    PHImageRequestOptions* requestOptions = [[PHImageRequestOptions alloc] init];
    requestOptions.networkAccessAllowed = YES;
    [[PHCachingImageManager defaultManager] requestImageForAsset:phAsset targetSize:cellSize contentMode:PHImageContentModeAspectFill options:requestOptions resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info) {
        [self.thumbnails setObject:result forKey:indexPath];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.collectionView reloadItemsAtIndexPaths:@[indexPath]];
        });
    }];
}

-(void) collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row == self.imageAssets.count || [self.imageAssets[indexPath.row] isKindOfClass:BlankImagePlaceHolder.class])
    {
        UIAlertController* alert = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
        // Set the sourceView.
        alert.popoverPresentationController.sourceView = collectionView;
        // Set the sourceRect.
        NSInteger rows = indexPath.row / 3;
        NSInteger cols = indexPath.row % 3;
        CGSize cellSize = [self collectionView:collectionView layout:collectionView.collectionViewLayout sizeForItemAtIndexPath:indexPath];
        alert.popoverPresentationController.sourceRect = CGRectMake((0.5f + cols) * cellSize.width, (0.5f + rows) * cellSize.height, 10, 10);
        // Create and add an Action.
        UIAlertAction* actionMultiImages = [UIAlertAction actionWithTitle:NSLocalizedString(@"SelectMultiImages", @"Select Multi Images") style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
            PhotoLibraryViewController* photoLibraryVC = [[UIStoryboard storyboardWithName:@"Main" bundle:[NSBundle mainBundle]] instantiateViewControllerWithIdentifier:@"PhotoLibrary"];
            //__weak PhotoLibraryViewController* wPLVC = photoLibraryVC;
            photoLibraryVC.maxSelectionCount = MaxCells - indexPath.row;
            photoLibraryVC.allowedMediaTypes = @[@(PHAssetMediaTypeImage)];
            photoLibraryVC.returnRawPHAssets = YES;
            photoLibraryVC.selectCompletion = ^(NSArray<PhotoLibrarySelectionItem* >* selectedItems) {
                for (NSUInteger offset = 0; offset < selectedItems.count; ++offset)
                {
                    PhotoLibrarySelectionItem* item = selectedItems[offset];
                    NSUInteger index = offset + indexPath.row;
                    if (index < self.imageAssets.count)
                    {
                        [self.imageAssets replaceObjectAtIndex:index withObject:item.resultOject];
                    }
                    else
                    {
                        [self.imageAssets addObject:item.resultOject];
                    }
                    [self.thumbnails removeObjectForKey:[NSIndexPath indexPathForRow:index inSection:0]];
                }
                self.navItem.rightBarButtonItem.enabled = YES;
                [self.collectionView reloadData];
                //            [self showActivityIndicatorViewInView:nil];
                
                CGSize cellSize = [self collectionView:collectionView layout:collectionView.collectionViewLayout sizeForItemAtIndexPath:indexPath];
                cellSize = CGSizeMake(cellSize.width * [UIScreen mainScreen].scale, cellSize.height * [UIScreen mainScreen].scale);
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    PHImageRequestOptions* requestOptions = [[PHImageRequestOptions alloc] init];
                    requestOptions.networkAccessAllowed = YES;
                    
                    NSInteger index = indexPath.row;
                    for (PhotoLibrarySelectionItem* item in selectedItems)
                    {
                        PHAsset* phAsset = (PHAsset*)item.resultOject;
                        [[PHCachingImageManager defaultManager] requestImageForAsset:phAsset targetSize:cellSize contentMode:PHImageContentModeAspectFill options:requestOptions resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info) {
                            NSIndexPath* indexPathDone = [NSIndexPath indexPathForRow:index inSection:0];
                            [self.thumbnails setObject:result forKey:indexPathDone];
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [self.collectionView reloadItemsAtIndexPaths:@[indexPathDone]];
                                //[self.collectionView reloadData];
                            });
                        }];
                        index++;
                    }
                });
            };
            [self presentViewController:photoLibraryVC animated:YES completion:nil];
        }];
        UIAlertAction* actionCaptureSnapshot = [UIAlertAction actionWithTitle:NSLocalizedString(@"CaptureVideoAndSnapshot", @"Capture Video and Take Snapshot") style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
            CameraDictateViewController* captureVC = [[UIStoryboard storyboardWithName:@"Main" bundle:[NSBundle mainBundle]] instantiateViewControllerWithIdentifier:@"CameraDictate"];
            captureVC.completeHandler = ^(NSString* filePath, NSString* dictateText) {
                if (filePath && [[NSFileManager defaultManager] fileExistsAtPath:filePath isDirectory:NULL])
                {
                    [self showActivityIndicatorViewInView:nil];
                    NSURL* videoURL = [NSURL fileURLWithPath:filePath];
                    [PhotoLibraryHelper saveVideoWithUrl:videoURL collectionTitle:@"CartoonShow" completionHandler:^(BOOL success, NSError *error, NSString *assetId) {
                        VideoSnapshotViewController* videoVC = [[UIStoryboard storyboardWithName:@"Main" bundle:[NSBundle mainBundle]] instantiateViewControllerWithIdentifier:@"VideoSnapshot"];
                        if (dictateText)
                        {
                            [videoVC setDictateInitText:dictateText];
                        }
                        videoVC.sourceVideoFile = filePath;
                        videoVC.completionHandler = ^(PHAsset* phAsset) {
                            [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
                            [self replaceOrAddPHAsset:phAsset atIndexPath:indexPath];
                        };
                        [self dismissActivityIndicatorView];
                        [self presentViewController:videoVC animated:YES completion:nil];
                    }];
                }
            };
            [self presentViewController:captureVC animated:YES completion:nil];
        }];
        
        UIAlertAction* actionVideoSnapshot = [UIAlertAction actionWithTitle:NSLocalizedString(@"PickVideoAndSnapshot", @"Pick Video and Take Snapshot") style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
            PhotoLibraryViewController* photoLibraryVC = [[UIStoryboard storyboardWithName:@"Main" bundle:[NSBundle mainBundle]] instantiateViewControllerWithIdentifier:@"PhotoLibrary"];
            //__weak PhotoLibraryViewController* wPLVC = photoLibraryVC;
            photoLibraryVC.maxSelectionCount = 1;
            photoLibraryVC.allowedMediaTypes = @[@(PHAssetMediaTypeVideo)];
            photoLibraryVC.returnRawPHAssets = NO;
            photoLibraryVC.selectCompletion = ^(NSArray<PhotoLibrarySelectionItem* >* selectedItems) {
                if (!selectedItems || selectedItems.count <= 0)
                    return;
                
                NSString* filePath = (NSString*)selectedItems[0].resultOject;
                //*
                [self showActivityIndicatorViewInView:nil];
                VideoSnapshotViewController* videoVC = [[UIStoryboard storyboardWithName:@"Main" bundle:[NSBundle mainBundle]] instantiateViewControllerWithIdentifier:@"VideoSnapshot"];
                videoVC.sourceVideoFile = filePath;
                videoVC.completionHandler = ^(PHAsset* phAsset) {
                    [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
                    [self replaceOrAddPHAsset:phAsset atIndexPath:indexPath];
                    [self dismissActivityIndicatorView];
                };
                /*/
                CameraPlayerViewController* videoVC = [[UIStoryboard storyboardWithName:@"Main" bundle:[NSBundle mainBundle]] instantiateViewControllerWithIdentifier:@"CameraPlayer"];
                filePath = [NSString stringWithFormat:@"%@", filePath];
                NSString* destPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0] stringByAppendingPathComponent:filePath.lastPathComponent];
                [[NSFileManager defaultManager] copyItemAtPath:filePath toPath:destPath error:nil];
                BOOL exist = [[NSFileManager defaultManager] fileExistsAtPath:destPath];
                videoVC.sourceVideoFile = destPath;
                //*/
                [self presentViewController:videoVC animated:YES completion:^() {
                }];
            };
            [self presentViewController:photoLibraryVC animated:YES completion:nil];
        }];
        
        UIAlertAction* actionCancel = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"Cancel") style:UIAlertActionStyleCancel handler:nil];
        [alert addAction:actionCaptureSnapshot];
        [alert addAction:actionVideoSnapshot];
        [alert addAction:actionMultiImages];
        [alert addAction:actionCancel];
        // Show the Alert.
        [self presentViewController:alert animated:YES completion:nil];
    }
    else if ([self.thumbnails objectForKey:indexPath])
    {
        [self showActivityIndicatorViewInView:nil];
        PHAsset* phAsset = (PHAsset*)self.imageAssets[indexPath.row];
        PHImageRequestOptions* requestOptions = [[PHImageRequestOptions alloc] init];
        requestOptions.networkAccessAllowed = YES;
        requestOptions.progressHandler = ^(double progress, NSError * _Nullable error, BOOL * _Nonnull stop, NSDictionary * _Nullable info) {
            if (progress < 1.0f)
            {
                [self showActivityIndicatorViewInView:nil withText:[NSString stringWithFormat:@"%0.0f%%", progress*100]];
            }
        };
        [[PHImageManager defaultManager] requestImageDataForAsset:phAsset options:requestOptions resultHandler:^(NSData * _Nullable imageData, NSString * _Nullable dataUTI, UIImageOrientation orientation, NSDictionary * _Nullable info) {
            UIImage* image = [UIImage imageWithData:imageData];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self dismissActivityIndicatorView];
                if (!image)
                    return;
                
                SnapshotEditorViewController* editorVC = [[UIStoryboard storyboardWithName:@"Main" bundle:[NSBundle mainBundle]] instantiateViewControllerWithIdentifier:@"SnapshotEditor"];
                editorVC.image = image;
                editorVC.completionHandler = ^(PHAsset* phAsset) {
                    [self replaceOrAddPHAsset:phAsset atIndexPath:indexPath];
                };
                [self presentViewController:editorVC animated:YES completion:^(){
                }];
            });
        }];
    }
}

-(void) shareLongImageToWeChatScene:(enum WXScene)wxScene {
    [self showActivityIndicatorViewInView:nil withText:NSLocalizedString(@"ProcessingImages", @"ProcessingImages")];
    
    NSMutableArray<PHAsset* >* phAssets = [[NSMutableArray alloc] init];
    for (id obj in self.imageAssets)
    {
        if (![obj isKindOfClass:PHAsset.class])
            continue;
        
        [phAssets insertObject:(PHAsset*)obj atIndex:0];
    }
    
    __block int jobFinished = 0;
    NSMutableDictionary<NSNumber*, UIImage* >* index2Image = [[NSMutableDictionary alloc] init];
    PHImageRequestOptions* requestOptions = [[PHImageRequestOptions alloc] init];
    requestOptions.networkAccessAllowed = YES;
    requestOptions.progressHandler = ^(double progress, NSError * _Nullable error, BOOL * _Nonnull stop, NSDictionary * _Nullable info) {
        //if (progress < 1.0f)
        {
            [self showActivityIndicatorViewInView:nil withText:[NSString stringWithFormat:@"%d/%d", (jobFinished+1), (int)phAssets.count]];
        }
    };
    for (NSUInteger i=0; i<phAssets.count; ++i)
    {
        PHAsset* phAsset = phAssets[i];
        [[PHImageManager defaultManager] requestImageDataForAsset:phAsset options:requestOptions resultHandler:^(NSData * _Nullable imageData, NSString * _Nullable dataUTI, UIImageOrientation orientation, NSDictionary * _Nullable info) {
            UIImage* img = [UIImage imageWithData:imageData];
            if (img)
            {
                [index2Image setObject:img forKey:@(i)];
            }
            if (++jobFinished == phAssets.count)
            {
                NSMutableArray<UIImage* >* images = [[NSMutableArray alloc] init];
                for (NSUInteger j=0; j<phAssets.count; ++j)
                {
                    UIImage* image = index2Image[@(j)];
                    image = [image imageScaledToFitMaxSize:CGSizeMake(MaxWidthOfImageToShare, MaxHeightOfImageToShare) orientation:UIImageOrientationUp];
                    if (image)
                    {
                        [images addObject:image];
                    }
                }
                UIImage* longImage = [UIImage longImageWithImages:images];
                NSData* longImageData = UIImageJPEGRepresentation(longImage, 1.0f);
                dispatch_async(dispatch_get_main_queue(), ^{
                    UIImage* thumbImage = [images[0] imageScaledToFitMaxSize:CGSizeMake(100, 100) orientation:UIImageOrientationUp];
                    ///dispatch_async(dispatch_get_main_queue(), ^{
                    BOOL succ = [WXApiRequestHandler sendImageData:longImageData
                                                           TagName:kImageTagName
                                                        MessageExt:kMessageExt
                                                            Action:kMessageAction
                                                        ThumbImage:thumbImage
                                                           InScene:wxScene];//WXSceneSession
                    [self dismissActivityIndicatorView];
                    if (!succ)
                    {
                        UIAlertController* alertCtrl = [UIAlertController alertControllerWithTitle:nil message:NSLocalizedString(@"ShareFailure", @"ShareFailure") preferredStyle:UIAlertControllerStyleAlert];
                        UIAlertAction* action = [UIAlertAction actionWithTitle:NSLocalizedString(@"GotIt", @"GotIt") style:UIAlertActionStyleDefault handler:nil];
                        [alertCtrl addAction:action];
                        [self showViewController:alertCtrl sender:self];
                    }
                });
            }
        }];
    }
}

-(void) confirm {
    UIAlertController* actionSheet = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    UIAlertAction* longImageTimelineAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"ShareLongImageToMoments", @"Long Image To Timeline") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self shareLongImageToWeChatScene:WXSceneTimeline];
    }];
    UIAlertAction* longImageSessionAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"ShareLongImageToSession", @"Long Image To Session") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self shareLongImageToWeChatScene:WXSceneSession];
    }];
    UIAlertAction* multiImageAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"ShareGridImages", @"Multi Image") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self showActivityIndicatorViewInView:nil withText:NSLocalizedString(@"ProcessingImages", @"ProcessingImages")];
        
        NSMutableArray<PHAsset* >* phAssets = [[NSMutableArray alloc] init];
        for (id obj in self.imageAssets)
        {
            if (![obj isKindOfClass:PHAsset.class])
                continue;
            
            [phAssets addObject:(PHAsset*)obj];
        }
        
        __block int jobFinished = 0;
        NSMutableDictionary<NSNumber*, NSData* >* index2Data = [[NSMutableDictionary alloc] init];
        PHImageRequestOptions* requestOptions = [[PHImageRequestOptions alloc] init];
        requestOptions.networkAccessAllowed = YES;
        requestOptions.progressHandler = ^(double progress, NSError * _Nullable error, BOOL * _Nonnull stop, NSDictionary * _Nullable info) {
            //if (progress < 1.0f)
            {
                [self showActivityIndicatorViewInView:nil withText:[NSString stringWithFormat:@"%d/%d", (jobFinished+1), (int)phAssets.count]];
            }
        };
        for (NSUInteger i=0; i<phAssets.count; ++i)
        {
            PHAsset* phAsset = phAssets[i];
            [[PHImageManager defaultManager] requestImageDataForAsset:phAsset options:requestOptions resultHandler:^(NSData * _Nullable imageData, NSString * _Nullable dataUTI, UIImageOrientation orientation, NSDictionary * _Nullable info) {
                if (imageData)
                {
                    [index2Data setObject:imageData forKey:@(i)];
                }
                if (++jobFinished == phAssets.count)
                {
                    NSMutableArray<NSData* >* imageDatas = [[NSMutableArray alloc] init];
                    for (NSUInteger j=0; j<phAssets.count; ++j)
                    {
                        NSData* data = index2Data[@(j)];
                        if (data)
                        {
                            [imageDatas addObject:data];
                        }
                    }
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self dismissActivityIndicatorView];
                        UIActivityViewController* activityVC = [[UIActivityViewController alloc] initWithActivityItems:imageDatas applicationActivities:nil];
                        [self presentViewController:activityVC animated:YES completion:nil];
                    });
                }
            }];
        }
    }];
    UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"Cancel") style:UIAlertActionStyleCancel handler:nil];
    [actionSheet addAction:longImageTimelineAction];
    [actionSheet addAction:longImageSessionAction];
    [actionSheet addAction:multiImageAction];
    [actionSheet addAction:cancelAction];
    [self showViewController:actionSheet sender:self];
}

-(void) viewDidLoad {
    [super viewDidLoad];
    
    self.okButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"share"]
                                                         style:UIBarButtonItemStylePlain
                                                        target:self
                                                        action:@selector(confirm)];
    self.okButtonItem.enabled = NO;
    self.navItem.rightBarButtonItem = self.okButtonItem;
    
    self.navItem.title = NSLocalizedString(@"AddMedias", @"Add Medias");
    
    [self.navBar makeTranslucent];
    [self setNeedsStatusBarAppearanceUpdate];
    
    self.imageAssets = [[NSMutableArray alloc] init];
    self.thumbnails = [[NSMutableDictionary alloc] init];
//    self.loadingCells = [[NSMutableSet alloc] init];
}

@end
