//
//  VideoCollectionViewController.m
//  PlayerCamera
//
//  Created by DOM QIU on 2018/5/20.
//  Copyright © 2018 DOM QIU. All rights reserved.
//

#import "VideoCollectionViewController.h"
#import "CameraPlayerViewController.h"
#import "IJKGPUImageMovie.h"
#import "UIImage+Blur.h"
#import <Photos/Photos.h>

NSString* VideoCollectionCellIdentifier = @"VideoCollectionCellIdentifier";

@interface VideoCollectionCell : UICollectionViewCell

@property (nonatomic, strong) IBOutlet UIImageView* thumbnailImageView;
@property (nonatomic, strong) IBOutlet UILabel* titleLabel;

@end

@implementation VideoCollectionCell

@end


@interface ThumbnailCacheItem : NSObject

@property (nonatomic, copy) NSString* key;
@property (nonatomic, strong) UIImage* thumbnail;

-(instancetype) initWithKey:(NSString*)key thumbnail:(UIImage*)thumbnail;

-(NSUInteger) cost;

@end

@implementation ThumbnailCacheItem

-(instancetype) initWithKey:(NSString*)key thumbnail:(UIImage*)thumbnail {
    if (self = [super init])
    {
        self.key = key;
        self.thumbnail = thumbnail;
    }
    return self;
}

-(NSUInteger) cost {
    if (!self.thumbnail)
        return 0;
    
    return (NSUInteger)self.thumbnail.size.width * (NSUInteger)self.thumbnail.size.height * 4;
}

@end


@interface VideoCollectionViewController () <UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, NSCacheDelegate, UINavigationControllerDelegate, UIImagePickerControllerDelegate>
{
    NSString* _docDirectoryPath;
    
    NSCache<NSString*, ThumbnailCacheItem* >* _thumbnailCache;
    
    NSMutableArray<NSString* >* _files;
}

@property (nonatomic, strong) IBOutlet UICollectionView* videoCollectionView;

@end

@implementation VideoCollectionViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    _thumbnailCache = [[NSCache alloc] init];
    _thumbnailCache.totalCostLimit = 1048576 * 16;
    _thumbnailCache.delegate = self;
    
    _files = [[NSMutableArray alloc] init];
//    [_files insertObject:@"rtsp://192.168.42.1/live" atIndex:0];
//    [_files insertObject:@"https://tzn8.com/bunnies.mp4" atIndex:0];
//    [_files insertObject:@"https://devstreaming-cdn.apple.com/videos/wwdc/2014/604xxg7crkljcr8/604/ipad_c.m3u8" atIndex:0];
    //    [_files insertObject:@"https://pan.baidu.com/play/video#/video?path=%2F20170820%2FMOVI0001_To0124_1207_1043_2101_2110_2010_2055_2135_0238%20-%20Segment11(00_24_10.000-00_26_11.560).mp4&t=-1" atIndex:0];
    
    NSFileManager* fm = [NSFileManager defaultManager];
    _docDirectoryPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    NSEnumerator<NSString* >* fileEnumerator = [fm enumeratorAtPath:_docDirectoryPath];
    for (NSString* file in fileEnumerator)
    {
        if ([file pathComponents].count > 1) continue;
        NSString* ext = [[file pathExtension] lowercaseString];
        if ([ext isEqualToString:@"mp4"] || [ext isEqualToString:@"avi"] || [ext isEqualToString:@"3gpp"] || [ext isEqualToString:@"mkv"] || [ext isEqualToString:@"rmvb"] || [ext isEqualToString:@"flv"] || [ext isEqualToString:@"mpg"] || [ext isEqualToString:@"mpeg"] || [ext isEqualToString:@"mov"] || [ext isEqualToString:@"rm"] || [ext isEqualToString:@"rmvb"] || [ext isEqualToString:@"m3u8"] || [ext isEqualToString:@"wmv"])
        {
            NSString* filePath = [_docDirectoryPath stringByAppendingPathComponent:file];
            [_files addObject:filePath];
            
        }
    }
    
//    for (NSString* fileURL in _files)
//    {
//        UIImage* thumbnail = nil;///!!![UIImage getVideoImage:filePath time:32.f];
//        if (!thumbnail)
//        {
//            thumbnail = [IJKGPUImageMovie imageOfVideo:fileURL atTime:CMTimeMake(32, 1)];
//        }
//        ThumbnailCacheItem* cacheItem = [[ThumbnailCacheItem alloc] initWithKey:fileURL thumbnail:thumbnail];
//        [_thumbnailCache setObject:cacheItem forKey:fileURL cost:cacheItem.cost];
//        ///!!!For Debug:
//        [self cache:_thumbnailCache willEvictObject:cacheItem];
//    }
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

-(NSString*) thumbnailPathForKey:(NSString*)key {
    key = [key stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    key = [key stringByReplacingOccurrencesOfString:@"\\" withString:@"_"];
    return [[[_docDirectoryPath stringByAppendingPathComponent:ThumbnailDirectory] stringByAppendingPathComponent:key] stringByAppendingPathExtension:@"thumb"];
}

#pragma mark NSCacheDelegate
- (void)cache:(NSCache *)cache willEvictObject:(id)obj {
    ThumbnailCacheItem* thumbnailItem = (ThumbnailCacheItem*)obj;
    NSData* thumbnailData = UIImagePNGRepresentation(thumbnailItem.thumbnail);
    NSString* thumbnailPath = [self thumbnailPathForKey:thumbnailItem.key];
    [thumbnailData writeToFile:thumbnailPath atomically:NO];
}

#pragma mark UICollectionViewDelegate
-(void) collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    /*/!!!For Test:
    UIImagePickerController* pickerVC = [[UIImagePickerController alloc] init];
    pickerVC.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    pickerVC.mediaTypes = @[@"public.image", @"public.movie"];
    pickerVC.delegate = self;
    [self presentViewController:pickerVC animated:YES completion:nil];
    /*/
    NSString* fileURL = [_files objectAtIndex:indexPath.row];
    CameraPlayerViewController* playerVC = [[UIStoryboard storyboardWithName:@"Main" bundle:[NSBundle mainBundle]] instantiateViewControllerWithIdentifier:@"CameraPlayer"];
    playerVC.sourceVideoFile = fileURL;
    [self presentViewController:playerVC animated:YES completion:nil];
    //*/
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info {
    NSURL* videoURL = info[@"UIImagePickerControllerReferenceURL"];
    if (videoURL)
    {
        NSLog(@"videoURL = %@", videoURL);
        CameraPlayerViewController* playerVC = [[UIStoryboard storyboardWithName:@"Main" bundle:[NSBundle mainBundle]] instantiateViewControllerWithIdentifier:@"CameraPlayer"];
        playerVC.sourceVideoFile = [videoURL absoluteString];
        [self presentViewController:playerVC animated:YES completion:nil];
    }
    [picker dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark UICollectionViewDataSource

-(NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return _files.count;
}

-(NSInteger) numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

-(__kindof UICollectionViewCell*) collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    VideoCollectionCell* cell = (VideoCollectionCell*) [collectionView dequeueReusableCellWithReuseIdentifier:VideoCollectionCellIdentifier forIndexPath:indexPath];
    NSString* fileURL = [_files objectAtIndex:indexPath.row];
    cell.titleLabel.text = [fileURL hasPrefix:_docDirectoryPath] ? fileURL.lastPathComponent : fileURL;
    ThumbnailCacheItem* cacheItem = [_thumbnailCache objectForKey:fileURL];
    if (!cacheItem || !cacheItem.thumbnail)
    {
        NSString* thumbnailPath = [self thumbnailPathForKey:fileURL];
        UIImage* thumbnail = nil;
        if ([[NSFileManager defaultManager] fileExistsAtPath:thumbnailPath])
        {
            thumbnail = [UIImage imageWithContentsOfFile:thumbnailPath];
            if (thumbnail)
            {
                cacheItem = [[ThumbnailCacheItem alloc] initWithKey:fileURL thumbnail:thumbnail];
                [_thumbnailCache setObject:cacheItem forKey:fileURL cost:cacheItem.cost];
            }
        }
        else
        {
//            thumbnail = [UIImage getVideoImage:filePath time:32.f];
//            if (!thumbnail)
//            {
//                thumbnail = [IJKGPUImageMovie imageOfVideo:fileURL atTime:CMTimeMake(32, 1)];
//            }
            [IJKGPUImageMovie imageOfVideo:fileURL atTime:CMTimeMake(45, 1) completionHandler:^(UIImage* image) {
                ThumbnailCacheItem* cacheItem = [[ThumbnailCacheItem alloc] initWithKey:fileURL thumbnail:image];
                [_thumbnailCache setObject:cacheItem forKey:fileURL cost:cacheItem.cost];
                
                NSData* thumbnailData = UIImagePNGRepresentation(image);
                NSString* thumbnailPath = [self thumbnailPathForKey:fileURL];
                [thumbnailData writeToFile:thumbnailPath atomically:NO];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.videoCollectionView reloadItemsAtIndexPaths:@[indexPath]];
                });
            }];
        }
    }
    cell.thumbnailImageView.image = cacheItem.thumbnail;
    return cell;
}

#pragma mark UICollectionViewDelegateFlowLayout


@end
