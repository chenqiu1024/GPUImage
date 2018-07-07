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

-(NSInteger) numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

-(NSInteger) collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.imageAssets.count == MaxCells ? MaxCells : self.imageAssets.count + 1;
}

-(void) deleteItemAt:(NSIndexPath*)indexPath {
    BlankImagePlaceHolder* placeHolder = [[BlankImagePlaceHolder alloc] init];
    [self.imageAssets replaceObjectAtIndex:indexPath.row withObject:placeHolder];
    [self.thumbnails removeObjectForKey:indexPath];
    [self.collectionView reloadItemsAtIndexPaths:@[indexPath]];
}

-(__kindof UICollectionViewCell*) collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    StartingGridCell* cell = [collectionView dequeueReusableCellWithReuseIdentifier:StartingGridCellIdentifier forIndexPath:indexPath];
    [cell.loadingView stopAnimating];
    cell.loadingView.hidden = YES;
    if (indexPath.row == self.imageAssets.count)
    {
        cell.numberLabel.hidden = NO;
        cell.numberLabel.text = [@(indexPath.row + 1) stringValue];
        cell.imageView.image = nil;
        cell.deleteButton.hidden = YES;
        cell.deleteButtonHandler = nil;
    }
    else
    {
        NSObject* item = self.imageAssets[indexPath.row];
        if ([item isKindOfClass:BlankImagePlaceHolder.class])
        {
            cell.numberLabel.hidden = NO;
            cell.numberLabel.text = [@(indexPath.row + 1) stringValue];
            cell.imageView.image = nil;
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

-(void) collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row == self.imageAssets.count || [self.imageAssets[indexPath.row] isKindOfClass:BlankImagePlaceHolder.class])
    {
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
    }
    else if ([self.thumbnails objectForKey:indexPath])
    {
        [self showActivityIndicatorViewInView:nil];
        PHAsset* phAsset = (PHAsset*)self.imageAssets[indexPath.row];
        PHImageRequestOptions* requestOptions = [[PHImageRequestOptions alloc] init];
        requestOptions.networkAccessAllowed = YES;
        [[PHImageManager defaultManager] requestImageDataForAsset:phAsset options:requestOptions resultHandler:^(NSData * _Nullable imageData, NSString * _Nullable dataUTI, UIImageOrientation orientation, NSDictionary * _Nullable info) {
            UIImage* image = [UIImage imageWithData:imageData];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self dismissActivityIndicatorView];
                SnapshotEditorViewController* editorVC = [[UIStoryboard storyboardWithName:@"Main" bundle:[NSBundle mainBundle]] instantiateViewControllerWithIdentifier:@"SnapshotEditor"];
                editorVC.image = image;
                [self presentViewController:editorVC animated:YES completion:^(){
                }];
            });
        }];
    }
}

-(void) confirm {
    
}

-(void) viewDidLoad {
    [super viewDidLoad];
    
    self.okButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"btn_back"]
                                                         style:UIBarButtonItemStylePlain
                                                        target:self
                                                        action:@selector(confirm)];
    self.okButtonItem.enabled = NO;
    self.navItem.rightBarButtonItem = self.okButtonItem;
    
    self.navItem.title = @"Select Photo/Video";
    
    [self.navBar makeTranslucent];
    [self setNeedsStatusBarAppearanceUpdate];
    
    self.imageAssets = [[NSMutableArray alloc] init];
    self.thumbnails = [[NSMutableDictionary alloc] init];
//    self.loadingCells = [[NSMutableSet alloc] init];
}

@end
