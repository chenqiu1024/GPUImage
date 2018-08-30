//
//  MediaCollectionWindowController.h
//  SimpleVideoFileFilter
//
//  Created by QiuDong on 2018/8/29.
//  Copyright © 2018年 Red Queen Coder, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface MediaCellModel : NSObject

@property (strong) NSImage* thumbnail;

@property (assign) float progress;

-(instancetype) initWithThumbnail:(NSImage*)thumbnail progress:(float)progress;

@end


@interface MediaCollectionViewItem : NSCollectionViewItem

@property (weak) IBOutlet NSProgressIndicator* progressIndicator;

@end


@interface MediaCollectionWindowController : NSWindowController <NSCollectionViewDataSource, NSCollectionViewDelegate>

@property (weak) IBOutlet NSCollectionView* collectionView;

@property (nonatomic, strong) NSArray* fileURLS;

@property (nonatomic, strong) NSMutableArray<NSString* >* sourceMediaPaths;
@property (nonatomic, strong) NSMutableDictionary<NSString*, MediaCellModel* >* sourceMediaModels;

-(void) setMediaTranscodingProgress:(float)progress fileURL:(NSString*)fileURL;
-(void) setMediaThumbnail:(NSImage*)thumbnail fileURL:(NSString*)fileURL;

-(void) reloadData;

-(void) refreshViews;

-(void) releaseResources;

-(instancetype) initWithCollectionView:(NSCollectionView*)collectionView;

@end
