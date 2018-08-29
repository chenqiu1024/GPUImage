//
//  MediaCollectionWindowController.m
//  SimpleVideoFileFilter
//
//  Created by QiuDong on 2018/8/29.
//  Copyright © 2018年 Red Queen Coder, LLC. All rights reserved.
//

#import "MediaCollectionWindowController.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>

NSImage* getVideoImage(NSString* videoURL, int timeMillSeconds, int destMinSize)
{
    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:[NSURL fileURLWithPath:videoURL] options:nil];
    AVAssetImageGenerator *gen = [[AVAssetImageGenerator alloc] initWithAsset:asset];
    gen.appliesPreferredTrackTransform = NO;///!!!
    CMTime ctime = CMTimeMake(timeMillSeconds, 1000);
    NSError *error = nil;
    CMTime actualTime;
    CGImageRef image = [gen copyCGImageAtTime:ctime actualTime:&actualTime error:&error];
    if (error)
        NSLog(@"#Bug3763# getVideoImage(%d) error:%@", timeMillSeconds, error);
    size_t videoWidth = CGImageGetWidth(image);
    size_t videoHeight = CGImageGetHeight(image);
    NSSize destSize;
    if (destMinSize > 0)
    {
        if (videoHeight > videoWidth)
            destSize = NSMakeSize(destMinSize, (float)destMinSize * (float)videoHeight / (float)videoWidth);
        else
            destSize = NSMakeSize((float)destMinSize * (float)videoWidth / (float)videoHeight, destMinSize);
    }
    else
    {
        destSize = NSMakeSize(videoWidth, videoHeight);
    }
    NSImage* thumb = [[NSImage alloc] initWithCGImage:image size:destSize];
    CGImageRelease(image);
    return thumb;
}

static NSUserInterfaceItemIdentifier mediaCellIdentifier = @"MediaCollectionViewItem";

@implementation MediaCollectionViewItem

@end


@interface MediaCollectionWindowController ()

@property (nonatomic, strong) NSMutableArray<NSString* >* sourceMediaPaths;
@property (nonatomic, strong) NSMutableDictionary<NSString*, NSImage* >* sourceMediaThumbnails;

@end

@implementation MediaCollectionWindowController

#pragma mark    Properties

-(void) reloadData {
    [self.sourceMediaPaths removeAllObjects];
    [self.sourceMediaThumbnails removeAllObjects];
    for (NSURL* url in self.fileURLS)
    {
        NSString* path = url.path;
        NSString* ext = path.pathExtension.lowercaseString;
        [self.sourceMediaPaths addObject:path];
        if ([ext isEqualToString:@"jpg"])
        {
            NSImage* thumbnail = [[NSImage alloc] initWithContentsOfFile:path];
            [self.sourceMediaThumbnails setObject:thumbnail forKey:path];
        }
        else if ([ext isEqualToString:@"dng"])
        {
            NSImage* thumbnail = [[NSImage alloc] initWithContentsOfFile:path];
            [self.sourceMediaThumbnails setObject:thumbnail forKey:path];
        }
        else
        {
            NSImage* thumbnail = getVideoImage(path, 99.f, -1);
            [self.sourceMediaThumbnails setObject:thumbnail forKey:path];
        }
    }
//    [self.collectionView reloadData];
}

#pragma mark    NSCollectionViewDataSource/Delegate/DelegateFlowLayout

- (NSInteger)collectionView:(NSCollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.sourceMediaPaths.count;
}

- (NSInteger)numberOfSectionsInCollectionView:(NSCollectionView *)collectionView {
    return 1;
}

- (NSCollectionViewItem *)collectionView:(NSCollectionView *)collectionView itemForRepresentedObjectAtIndexPath:(NSIndexPath *)indexPath {
    NSCollectionViewItem* cellItem = [collectionView makeItemWithIdentifier:mediaCellIdentifier forIndexPath:indexPath];
    NSString* path = self.sourceMediaPaths[indexPath.item];
    [cellItem.imageView setToolTip:path];
    NSImage* image = [self.sourceMediaThumbnails objectForKey:path];
    [cellItem.imageView setImage:image];
    return cellItem;
}

- (NSView *)collectionView:(NSCollectionView *)collectionView viewForSupplementaryElementOfKind:(NSCollectionViewSupplementaryElementKind)kind atIndexPath:(NSIndexPath *)indexPath {
    return nil;
}

#pragma mark    LifeCycle

-(void) awakeFromNib {
    self.sourceMediaPaths = [[NSMutableArray alloc] init];
    self.sourceMediaThumbnails = [[NSMutableDictionary alloc] init];
    [self reloadData];
    
    NSNib* mediaCellNib = [[NSNib alloc] initWithNibNamed:@"MediaCollectionViewItem" bundle:[NSBundle mainBundle]];
    [self.collectionView registerNib:mediaCellNib forItemWithIdentifier:mediaCellIdentifier];
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    
//    [self.collectionView registerClass:MediaCollectionViewItem.class forItemWithIdentifier:mediaCellIdentifier];
//    [self reloadData];
}

@end
