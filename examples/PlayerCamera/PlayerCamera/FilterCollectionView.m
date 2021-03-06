//
//  FilterCollectionView.m
//  PlayerCamera
//
//  Created by DOM QIU on 2018/7/8.
//  Copyright © 2018 DOM QIU. All rights reserved.
//

#import "FilterCollectionView.h"

#define LogoWidth 50.f
#define LogoHeight 50.f

typedef enum : int {
    NoFilter = 0,
    ToonFilter,
    SketchFilter,
    Laplacian,
    SepiaFilter,
//    Mosaic,
    Grayscale,
    ComplementFilter,
    Halftone,
    SobelEdgeDetection,
    SmoothToon,
    Emboss,
    Dilation,
//    Amatorka,
//    MissEtikate,
} FilterID;

static const char* filterLogos[] = {"origin", "toon", "sketch", "laplacian", "sepia", "grayscale", "complement", "halftone", "sobeledge", "smoothtoon", "emboss", "dilation"};

static GPUImageFilter* createFilterByID(int filterID) {
    switch (filterID)
    {
        case Dilation:
        {
            GPUImageDilationFilter* filter = [[GPUImageDilationFilter alloc] init];
            return filter;
        }
        case Emboss:
        {
            GPUImageEmbossFilter* filter = [[GPUImageEmbossFilter alloc] init];
            return filter;
        }
        case SmoothToon:
        {
            GPUImageSmoothToonFilter* filter = [[GPUImageSmoothToonFilter alloc] init];
            return filter;
        }
        case SobelEdgeDetection:
        {
            GPUImageSobelEdgeDetectionFilter* filter = [[GPUImageSobelEdgeDetectionFilter alloc] init];
            return filter;
        }
        case Halftone:
        {
            GPUImageHalftoneFilter* filter = [[GPUImageHalftoneFilter alloc] init];
            return filter;
        }
        case Laplacian:
        {
            GPUImageLaplacianFilter* filter = [[GPUImageLaplacianFilter alloc] init];
            return filter;
        }
//        case Mosaic:
//        {
//            GPUImageMosaicFilter* filter = [[GPUImageMosaicFilter alloc] init];
//            [filter setTileSet:@"dotletterstiles.png"];
//            [filter setColorOn:NO];
//            return filter;
//        }
        case Grayscale:
        {
            GPUImageGrayscaleFilter* filter = [[GPUImageGrayscaleFilter alloc] init];
            return filter;
        }
        case ToonFilter:
        {
            GPUImageToonFilter* toonFilter = [[GPUImageToonFilter alloc] init];
            toonFilter.threshold = 0.5f;
            toonFilter.quantizationLevels = 10.f;
            return toonFilter;
        }
        case SketchFilter:
        {
            GPUImageSketchFilter* sketchFilter = [[GPUImageSketchFilter alloc] init];
            return sketchFilter;
        }
        case SepiaFilter:
        {
            GPUImageSepiaFilter* filter = [[GPUImageSepiaFilter alloc] init];
            return filter;
        }
        case ComplementFilter:
        {
            GPUImageColorInvertFilter* filter = [[GPUImageColorInvertFilter alloc] init];
            return filter;
        }
        default:
            return nil;
    }
}

static NSString* FilterCellIdentifier = @"FilterCell";

@interface FilterCollectionViewCell : UICollectionViewCell

@property (nonatomic, strong) IBOutlet UIImageView* imageView;

@end

@implementation FilterCollectionViewCell

@end

@interface FilterCollectionView () <UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>
{
    NSMutableDictionary<NSNumber*, GPUImageFilter* >* _filtersCache;
}

@end

@implementation FilterCollectionView

-(void) awakeFromNib {
    [super awakeFromNib];
    
    _filtersCache = [[NSMutableDictionary alloc] init];
    
    self.dataSource = self;
    self.delegate = self;
}

-(NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return sizeof(filterLogos) / sizeof(filterLogos[0]);
}

-(NSInteger) numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

-(__kindof UICollectionViewCell*) collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    FilterCollectionViewCell* cell = (FilterCollectionViewCell*) [collectionView dequeueReusableCellWithReuseIdentifier:FilterCellIdentifier forIndexPath:indexPath];
    cell.imageView.image = [UIImage imageNamed:[NSString stringWithUTF8String:filterLogos[indexPath.row]]];
    return cell;
}

-(void) collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    GPUImageFilter* nextFilter = [_filtersCache objectForKey:@(indexPath.row)];
    if (!nextFilter)
    {
        nextFilter = createFilterByID((int)indexPath.row);
        if (nextFilter)
            [_filtersCache setObject:nextFilter forKey:@(indexPath.row)];
    }
    
    if (self.filterSelectedHandler)
    {
        self.filterSelectedHandler(nextFilter);
    }
}

-(CGSize) collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    return CGSizeMake(self.bounds.size.height * LogoWidth / LogoHeight, self.bounds.size.height);
}

@end
