//
//  MediaCollectionWindowController.h
//  SimpleVideoFileFilter
//
//  Created by QiuDong on 2018/8/29.
//  Copyright © 2018年 Red Queen Coder, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface MediaCollectionViewItem : NSCollectionViewItem

@property (weak) IBOutlet NSProgressIndicator* progressIndicator;

@end


@interface MediaCollectionWindowController : NSWindowController <NSCollectionViewDataSource, NSCollectionViewDelegate>

@property (weak) IBOutlet NSCollectionView* collectionView;

@property (nonatomic, strong) NSArray* fileURLS;

@end
