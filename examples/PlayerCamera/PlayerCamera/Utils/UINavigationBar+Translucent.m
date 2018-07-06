//
//  UINavigationBar+Translucent.m
//  PlayerCamera
//
//  Created by DOM QIU on 2018/7/6.
//  Copyright © 2018 DOM QIU. All rights reserved.
//

#import "UINavigationBar+Translucent.h"

@implementation UINavigationBar (Translucent)
// https://www.jianshu.com/p/fa27ab9fb172
-(void) makeTranslucent {
    self.backgroundColor = [UIColor clearColor];
    self.barTintColor = [UIColor clearColor];
    self.translucent = YES;
    UIColor* translucentColor = [UIColor clearColor];
    CGRect rect = CGRectMake(0, 0, self.bounds.size.width, 64);
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(context, [translucentColor CGColor]);
    CGContextFillRect(context, rect);
    UIImage* image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    [self setShadowImage:image];
    [self setBackgroundImage:image forBarMetrics:UIBarMetricsDefault];
}

@end
