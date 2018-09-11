//
//  MediaCollectionWindowController.m
//  SimpleVideoFileFilter
//
//  Created by QiuDong on 2018/8/29.
//  Copyright © 2018年 Red Queen Coder, LLC. All rights reserved.
//

#import "MediaCollectionWindowController.h"
#import <MADVPanoFramework_macOS/MADVPanoFramework_macOS.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>

NSImage* getVideoThumbnail(NSString* videoURL, int timeMillSeconds, float destMaxSize)
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
    if (videoHeight > videoWidth)
        destSize = NSMakeSize(destMaxSize, destMaxSize * (float)videoHeight / (float)videoWidth);
    else
        destSize = NSMakeSize(destMaxSize * (float)videoWidth / (float)videoHeight, destMaxSize);
    NSImage* thumb = [[NSImage alloc] initWithCGImage:image size:destSize];
    CGImageRelease(image);
    return thumb;
}

static NSUserInterfaceItemIdentifier mediaCellIdentifier = @"MediaCollectionViewItem";

@implementation MediaCellModel

-(instancetype) initWithThumbnail:(NSImage*)thumbnail progress:(float)progress {
    if (self = [super init])
    {
        self.thumbnail = thumbnail;
        self.progress = progress;
    }
    return self;
}

@end


@implementation MediaCollectionViewItem

@end


@interface MediaCollectionWindowController ()

@end

@implementation MediaCollectionWindowController

#pragma mark    Properties

-(void) setMediaTranscodingProgress:(float)progress fileURL:(NSString*)fileURL {
    MediaCellModel* model = [self.sourceMediaModels objectForKey:fileURL];
    if (!model)
    {
        model = [[MediaCellModel alloc] initWithThumbnail:nil progress:progress];
        [self.sourceMediaModels setObject:model forKey:fileURL];
    }
    else
    {
        model.progress = progress;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [self refreshViews];
    });
}

-(void) setMediaThumbnail:(NSImage*)thumbnail fileURL:(NSString*)fileURL {
    MediaCellModel* model = [self.sourceMediaModels objectForKey:fileURL];
    if (!model)
    {
        model = [[MediaCellModel alloc] initWithThumbnail:thumbnail progress:-1.f];
        [self.sourceMediaModels setObject:model forKey:fileURL];
    }
    else
    {
        model.thumbnail = thumbnail;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [self refreshViews];
    });
}

-(void) reloadData {
    [self.sourceMediaPaths removeAllObjects];
    [self.sourceMediaModels removeAllObjects];
    NSString* documentDirectory = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
    for (NSURL* url in self.fileURLS)
    {
        NSString* path = url.path;
        NSString* ext = path.pathExtension.lowercaseString;
        [self.sourceMediaPaths addObject:path];
        NSImage* thumbnail;
        if ([ext isEqualToString:@"jpg"])
        {
            NSString* destPath = [documentDirectory stringByAppendingPathComponent:[[path.lastPathComponent stringByDeletingPathExtension] stringByAppendingString:@"_thumbnail.jpg"]];
            NSString* tempLUTDirectory = makeTempLUTDirectory(path);
            MadvGLRenderer::renderMadvJPEGToJPEG(destPath.UTF8String, path.UTF8String, tempLUTDirectory.UTF8String, 256, 128, true);
            thumbnail = [[NSImage alloc] initWithContentsOfFile:destPath];
            unlink(destPath.UTF8String);
        }
        else if ([ext isEqualToString:@"dng"])
        {
            NSString* destPath = [documentDirectory stringByAppendingPathComponent:[[path.lastPathComponent stringByDeletingPathExtension] stringByAppendingString:@"_thumbnail.dng"]];
            NSString* tempLUTDirectory = makeTempLUTDirectory(path);
            MadvGLRenderer::renderMadvRawToRaw(destPath.UTF8String, path.UTF8String, tempLUTDirectory.UTF8String, 256, 128, true);
            thumbnail = [[NSImage alloc] initWithContentsOfFile:destPath];
            unlink(destPath.UTF8String);
        }
        else
        {
            thumbnail = getVideoThumbnail(path, 99.f, 100.f);
        }
        MediaCellModel* model = [[MediaCellModel alloc] initWithThumbnail:thumbnail progress:-1.f];
        [self.sourceMediaModels setObject:model forKey:path];
    }
}

-(void) refreshViews {
    NSIndexSet* indexSet = [[NSIndexSet alloc] initWithIndexesInRange:NSMakeRange(0, 1)];
    [self.collectionView reloadSections:indexSet];
}

#pragma mark    NSCollectionViewDataSource/Delegate/DelegateFlowLayout

- (NSInteger)collectionView:(NSCollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.sourceMediaPaths.count;
}

- (NSInteger)numberOfSectionsInCollectionView:(NSCollectionView *)collectionView {
    return 1;
}

- (NSCollectionViewItem *)collectionView:(NSCollectionView *)collectionView itemForRepresentedObjectAtIndexPath:(NSIndexPath *)indexPath {
    MediaCollectionViewItem* cellItem = (MediaCollectionViewItem*)[collectionView makeItemWithIdentifier:mediaCellIdentifier forIndexPath:indexPath];
    NSString* path = self.sourceMediaPaths[indexPath.item];
    [cellItem.imageView setToolTip:path];
    MediaCellModel* model = [self.sourceMediaModels objectForKey:path];
    [cellItem.imageView setImage:model.thumbnail];
    cellItem.imageView.alphaValue = (model.progress < 1.f ? 0.5f : 1.0f);
    if (model.progress < 0.f || model.progress >= 1.f)
    {
        [cellItem.progressIndicator stopAnimation:self];
        cellItem.progressIndicator.hidden = YES;
    }
    else
    {
        cellItem.progressIndicator.hidden = NO;
        [cellItem.progressIndicator startAnimation:self];
        cellItem.progressIndicator.doubleValue = model.progress;
    }
    return cellItem;
}

- (NSView *)collectionView:(NSCollectionView *)collectionView viewForSupplementaryElementOfKind:(NSCollectionViewSupplementaryElementKind)kind atIndexPath:(NSIndexPath *)indexPath {
    return nil;
}

#pragma mark    LifeCycle

-(void) dealloc {
    [self releaseResources];
}

-(void) releaseResources {
    [self.sourceMediaPaths removeAllObjects];
    [self.sourceMediaModels removeAllObjects];
}

-(instancetype) initWithWindowNibName:(NSNibName)windowNibName {
    if (self = [super initWithWindowNibName:windowNibName])
    {
        self.sourceMediaPaths = [[NSMutableArray alloc] init];
        self.sourceMediaModels = [[NSMutableDictionary alloc] init];
    }
    return self;
}

-(instancetype) initWithCollectionView:(NSCollectionView*)collectionView {
    if (self = [super init])
    {
        self.collectionView = collectionView;
        self.sourceMediaPaths = [[NSMutableArray alloc] init];
        self.sourceMediaModels = [[NSMutableDictionary alloc] init];
        [self awakeFromNib];
    }
    return self;
}

-(void) awakeFromNib {
    self.collectionView.dataSource = self;
    self.collectionView.delegate = self;
    NSNib* mediaCellNib = [[NSNib alloc] initWithNibNamed:@"MediaCollectionViewItem" bundle:[NSBundle mainBundle]];
    [self.collectionView registerNib:mediaCellNib forItemWithIdentifier:mediaCellIdentifier];
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    
//    [self.collectionView registerClass:MediaCollectionViewItem.class forItemWithIdentifier:mediaCellIdentifier];
//    dispatch_async(dispatch_get_main_queue(), ^{
//        self.collectionView.dataSource = self;
//        self.collectionView.delegate = self;
//        [self reloadData];
//    });
}

@end
