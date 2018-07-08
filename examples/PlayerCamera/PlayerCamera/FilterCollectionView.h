//
//  FilterCollectionView.h
//  PlayerCamera
//
//  Created by DOM QIU on 2018/7/8.
//  Copyright © 2018 DOM QIU. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "GPUImage.h"

typedef void(^FilterSelectedHandler)(GPUImageFilter* filter);

@interface FilterCollectionView : UICollectionView

@property (nonatomic, copy) FilterSelectedHandler filterSelectedHandler;

@end
