//
//  StartingGridViewController.m
//  PlayerCamera
//
//  Created by DOM QIU on 2018/7/7.
//  Copyright © 2018 DOM QIU. All rights reserved.
//

#import "StartingGridViewController.h"
#import "UINavigationBar+Translucent.h"

static NSString* StartingGridCellIdentifier = @"StartingGrid";

@interface StartingGridCell : UICollectionViewCell

@property (nonatomic, weak) IBOutlet UIImageView* imageView;

@end

@implementation StartingGridCell
@end

@interface StartingGridViewController () <UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, UICollectionViewDataSource>

@property (nonatomic, weak) IBOutlet UICollectionView* collectionView;

@property (nonatomic, weak) IBOutlet UINavigationBar* navBar;
@property (nonatomic, weak) IBOutlet UINavigationItem* navItem;
@property (nonatomic, strong) UIBarButtonItem* okButtonItem;

@end

@implementation StartingGridViewController

-(NSInteger) numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

-(NSInteger) collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return 8;
}

-(__kindof UICollectionViewCell*) collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    StartingGridCell* cell = [collectionView dequeueReusableCellWithReuseIdentifier:StartingGridCellIdentifier forIndexPath:indexPath];
    cell.imageView.image = [UIImage imageNamed:@"AppIcon"];
    return cell;
}

-(CGSize) collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat size = (self.collectionView.bounds.size.width - 6) / 3;
    return CGSizeMake(size, size);
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
}

@end
