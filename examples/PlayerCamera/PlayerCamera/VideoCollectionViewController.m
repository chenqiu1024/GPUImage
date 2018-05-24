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


@interface VideoCollectionViewController () <UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, NSCacheDelegate>
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
    NSFileManager* fm = [NSFileManager defaultManager];
    _docDirectoryPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    NSEnumerator<NSString* >* fileEnumerator = [fm enumeratorAtPath:_docDirectoryPath];
    for (NSString* file in fileEnumerator)
    {
        if ([file pathComponents].count > 1) continue;
        NSString* ext = [[file pathExtension] lowercaseString];
        if ([ext isEqualToString:@"mp4"] || [ext isEqualToString:@"avi"] || [ext isEqualToString:@"3gpp"] || [ext isEqualToString:@"mkv"] || [ext isEqualToString:@"rmvb"] || [ext isEqualToString:@"flv"] || [ext isEqualToString:@"mpg"] || [ext isEqualToString:@"mpeg"])
        {
            [_files addObject:file];
            NSString* filePath = [_docDirectoryPath stringByAppendingPathComponent:file];
            UIImage* thumbnail = nil;///!!![UIImage getVideoImage:filePath time:32.f];
            if (!thumbnail)
            {
                thumbnail = [IJKGPUImageMovie imageOfVideo:filePath atTime:CMTimeMake(32, 1)];
            }
            ThumbnailCacheItem* cacheItem = [[ThumbnailCacheItem alloc] initWithKey:file thumbnail:thumbnail];
            [_thumbnailCache setObject:cacheItem forKey:file cost:cacheItem.cost];
            ///!!!For Debug:
            [self cache:_thumbnailCache willEvictObject:cacheItem];
        }
    }
    [_files insertObject:@"rtsp://192.168.42.1/live" atIndex:0];
    [_files insertObject:@"https://tzn8.com/bunnies.mp4" atIndex:0];
    
//    CameraPlayerViewController* playerVC = [[UIStoryboard storyboardWithName:@"Main" bundle:[NSBundle mainBundle]] instantiateViewControllerWithIdentifier:@"CameraPlayer"];
//    [self presentViewController:playerVC animated:YES completion:nil];///!!!For Debug
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
    NSString* file = [_files objectAtIndex:indexPath.row];
    NSString* filePath = [_docDirectoryPath stringByAppendingPathComponent:file];
    CameraPlayerViewController* playerVC = [[UIStoryboard storyboardWithName:@"Main" bundle:[NSBundle mainBundle]] instantiateViewControllerWithIdentifier:@"CameraPlayer"];
    playerVC.sourceVideoFile = filePath;
    [self presentViewController:playerVC animated:YES completion:nil];
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
    NSString* file = [_files objectAtIndex:indexPath.row];
    cell.titleLabel.text = file;
    ThumbnailCacheItem* cacheItem = [_thumbnailCache objectForKey:file];
    if (!cacheItem || !cacheItem.thumbnail)
    {
        NSString* thumbnailPath = [self thumbnailPathForKey:cacheItem.key];
        UIImage* thumbnail;
        if ([[NSFileManager defaultManager] fileExistsAtPath:thumbnailPath])
        {
            thumbnail = [UIImage imageWithContentsOfFile:thumbnailPath];
        }
        else
        {
            NSString* filePath = [_docDirectoryPath stringByAppendingPathComponent:file];
            thumbnail = nil;///!!![UIImage getVideoImage:filePath time:32.f];
            if (!thumbnail)
            {
                ///!!!thumbnail = [IJKGPUImageMovie imageOfVideo:filePath atTime:CMTimeMake(32, 1)];
            }
        }
        cacheItem = [[ThumbnailCacheItem alloc] initWithKey:file thumbnail:thumbnail];
        [_thumbnailCache setObject:cacheItem forKey:file cost:cacheItem.cost];
    }
    cell.thumbnailImageView.image = cacheItem.thumbnail;
    return cell;
}

#pragma mark UICollectionViewDelegateFlowLayout


@end
