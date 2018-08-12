//
//  UIImage+Share.h
//  GijkPlayer
//
//  Created by DOM QIU on 2018/6/30.
//  Copyright © 2018 DOM QIU. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIImage (Share)

-(UIImage*) imageScaledToFitMaxSize:(CGSize)maxSize orientation:(UIImageOrientation)orientation;

+(UIImage*) longImageWithImages:(NSArray<UIImage* >*)images;

+(UIImage*) fixOrientation:(UIImage*)aImage;

@end
